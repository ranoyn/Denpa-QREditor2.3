// Read-only catalogue using the existing Tropic preview artwork. No QR/editor mutations.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Windows.Forms;

namespace DenpaPartsCatalogue {
public sealed class PartsGrid : DataGridView { public PartsGrid(){ DoubleBuffered=true; } }
public sealed class PartsWindow : Form {
    static readonly string[] folders={"heads","hairs","outlines","brows","eyes","noses","mouths","cheeks"};
    static readonly string[] jp={"頭","髪","輪郭","眉","目","鼻","口","頬"};
    static readonly string[] en={"Head","Hair","Face shape","Brow","Eye","Nose","Mouth","Cheek"};
    static readonly int[] zoomValues={50,75,100,125,150,200};
    readonly List<Bitmap> ownedImages=new List<Bitmap>();
    public readonly PartsGrid Grid=new PartsGrid();
    public readonly ComboBox ZoomControl=new ComboBox();
    public int PartCount {get;private set;}
    public int DetailOpenCount {get;private set;}
    public int ZoomPercent {get;private set;}

    public PartsWindow(string root,bool english,string game) {
        if(!Directory.Exists(root))throw new DirectoryNotFoundException(english?"Preview artwork was not found.":"プレビュー素材が見つかりません。");
        Text=(english?"Face Parts Table":"顔パーツ表")+" - "+game;
        Name="facePartsTableWindow";StartPosition=FormStartPosition.CenterParent;
        ClientSize=new Size(850,580);MinimumSize=new Size(660,460);
        Font=new Font("Yu Gothic UI",10);BackColor=Color.White;ShowInTaskbar=false;
        Panel top=new Panel();
        Label zoomLabel=new Label();zoomLabel.AutoSize=true;zoomLabel.Text=english?"Zoom":"表示倍率";zoomLabel.Location=new Point(12,15);top.Controls.Add(zoomLabel);
        ZoomControl.Name="partsZoom";ZoomControl.DropDownStyle=ComboBoxStyle.DropDownList;ZoomControl.SetBounds(98,10,105,27);
        foreach(int value in zoomValues)ZoomControl.Items.Add(value+"%");top.Controls.Add(ZoomControl);
        Grid.Name="facePartsGrid";Grid.Dock=DockStyle.Fill;Grid.BackgroundColor=Color.White;
        Grid.ReadOnly=true;Grid.AllowUserToAddRows=false;Grid.AllowUserToDeleteRows=false;Grid.AllowUserToOrderColumns=false;
        Grid.AllowUserToResizeRows=false;Grid.RowHeadersVisible=false;Grid.AutoGenerateColumns=false;
        Grid.MultiSelect=false;Grid.SelectionMode=DataGridViewSelectionMode.CellSelect;Grid.EditMode=DataGridViewEditMode.EditProgrammatically;
        Grid.EnableHeadersVisualStyles=false;Grid.ColumnHeadersDefaultCellStyle.BackColor=Color.FromArgb(217,238,250);
        Grid.ColumnHeadersDefaultCellStyle.ForeColor=Color.FromArgb(32,56,77);Grid.ColumnHeadersDefaultCellStyle.Alignment=DataGridViewContentAlignment.MiddleCenter;
        Grid.ColumnHeadersHeight=38;Grid.ColumnHeadersHeightSizeMode=DataGridViewColumnHeadersHeightSizeMode.DisableResizing;
        Grid.DefaultCellStyle.BackColor=Color.White;Grid.DefaultCellStyle.ForeColor=Color.FromArgb(32,56,77);
        Grid.DefaultCellStyle.SelectionBackColor=Color.FromArgb(227,240,250);Grid.DefaultCellStyle.SelectionForeColor=Color.FromArgb(32,56,77);
        Grid.AlternatingRowsDefaultCellStyle.BackColor=Color.FromArgb(241,247,251);Grid.GridColor=Color.FromArgb(213,225,233);
        Grid.CellBorderStyle=DataGridViewCellBorderStyle.SingleHorizontal;
        DataGridViewTextBoxColumn number=new DataGridViewTextBoxColumn();number.Name="number";number.HeaderText=english?"No.":"番号";
        number.Frozen=true;number.Width=62;number.SortMode=DataGridViewColumnSortMode.NotSortable;
        number.DefaultCellStyle.Alignment=DataGridViewContentAlignment.MiddleCenter;Grid.Columns.Add(number);
        for(int c=0;c<folders.Length;c++){
            DataGridViewImageColumn col=new DataGridViewImageColumn();col.Name=folders[c];col.HeaderText=english?en[c]:jp[c];
            col.ImageLayout=DataGridViewImageCellLayout.Zoom;col.SortMode=DataGridViewColumnSortMode.NotSortable;
            col.DefaultCellStyle.NullValue=null;col.DefaultCellStyle.Padding=new Padding(10);Grid.Columns.Add(col);
        }
        TableLayoutPanel layout=new TableLayoutPanel();layout.Dock=DockStyle.Fill;layout.ColumnCount=1;layout.RowCount=2;
        layout.Margin=Padding.Empty;layout.Padding=Padding.Empty;layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute,48));layout.RowStyles.Add(new RowStyle(SizeType.Percent,100));
        top.Dock=DockStyle.Fill;
        top.Margin=Padding.Empty;Grid.Margin=Padding.Empty;
        layout.Controls.Add(top,0,0);layout.Controls.Add(Grid,0,1);Controls.Add(layout);
        // The supplied sheet is pre-tinted and pre-trimmed at build time.
        // Opening the viewer decodes one PNG, never the 240 original files.
        string[] entries=File.ReadAllLines(Path.Combine(root,"face-parts-atlas.tsv"));
        int rows;
        string[] header=entries.Length==0?new string[0]:entries[0].Split('\t');
        if(header.Length!=2||header[0]!="DENPA_PARTS_ATLAS_1"||!Int32.TryParse(header[1],out rows)||rows<1||rows>256)throw new InvalidDataException("Invalid face parts atlas index.");
        Grid.SuspendLayout();
        try{for(int code=0;code<rows;code++){
            int row=Grid.Rows.Add();Grid.Rows[row].Cells[0].Value=code.ToString("D2");
        }
        using(Bitmap atlas=DecodeAtlas(Path.Combine(root,"face-parts-atlas.png"))){
            for(int i=1;i<entries.Length;i++){
                string[] fields=entries[i].Split('\t');int code,c,x,y,w,h;
                if(fields.Length!=6||!Int32.TryParse(fields[0],out code)||!Int32.TryParse(fields[1],out c)||!Int32.TryParse(fields[2],out x)||!Int32.TryParse(fields[3],out y)||!Int32.TryParse(fields[4],out w)||!Int32.TryParse(fields[5],out h)||code<0||code>=rows||c<0||c>=folders.Length||x<0||y<0||w<1||h<1||w>atlas.Width||h>atlas.Height||x>atlas.Width-w||y>atlas.Height-h)throw new InvalidDataException("Invalid face parts atlas rectangle.");
                DataGridViewCell cell=Grid.Rows[code].Cells[c+1];
                if(cell.Value!=null)throw new InvalidDataException("Duplicate face parts atlas entry.");
                Bitmap image=atlas.Clone(new Rectangle(x,y,w,h),PixelFormat.Format32bppArgb);
                ownedImages.Add(image);cell.Value=image;cell.ToolTipText=(english?en[c]:jp[c])+" "+code.ToString("D2");PartCount++;
            }
        }}catch{Dispose();throw;}finally{if(!Grid.IsDisposed)Grid.ResumeLayout();}
        ZoomControl.SelectedIndexChanged+=delegate{int index=ZoomControl.SelectedIndex;if(index>=0)SetZoom(zoomValues[index]);};
        ZoomControl.SelectedItem="100%";
        Grid.CellClick+=delegate(object sender,DataGridViewCellEventArgs e){if(e.RowIndex>=0&&e.ColumnIndex>0)OpenDetail(e.RowIndex,e.ColumnIndex);};
    }
    public void SetZoom(int percent){
        if(percent<50||percent>250)throw new ArgumentOutOfRangeException("percent");ZoomPercent=percent;
        Grid.SuspendLayout();try{
            // New 100% is the former 75%; all zoom levels use this base.
            foreach(DataGridViewRow row in Grid.Rows)row.Height=(int)Math.Round(86*0.75*percent/100.0);
            for(int i=1;i<Grid.Columns.Count;i++)Grid.Columns[i].Width=(int)Math.Round(128*0.75*percent/100.0);
        }finally{Grid.ResumeLayout();}
    }
    public Form CreateDetail(int row,int column){
        Image image=Grid.Rows[row].Cells[column].Value as Image;if(image==null)return null;
        Form detail=new Form();detail.Name="facePartDetailWindow";detail.Text=Grid.Columns[column].HeaderText+" "+Grid.Rows[row].Cells[0].Value;
        detail.StartPosition=FormStartPosition.CenterParent;detail.ClientSize=new Size(460,380);detail.MinimumSize=new Size(240,220);detail.ShowInTaskbar=false;
        if(Icon!=null)detail.Icon=Icon;
        PictureBox picture=new PictureBox();picture.Dock=DockStyle.Fill;picture.BackColor=Color.White;picture.Padding=new Padding(24);
        picture.SizeMode=PictureBoxSizeMode.Zoom;picture.Image=new Bitmap(image);detail.Controls.Add(picture);
        detail.Disposed+=delegate{if(picture.Image!=null){picture.Image.Dispose();picture.Image=null;}};
        return detail;
    }
    public void OpenDetail(int row,int column){Form detail=CreateDetail(row,column);if(detail!=null){DetailOpenCount++;detail.Show(this);}}
    static Bitmap DecodeAtlas(string path){
        // Materialize PNG pixels once: GDI+ can otherwise repeat lazy decoding
        // when Clone is called for multiple source rectangles.
        using(Bitmap source=new Bitmap(path)){
            Bitmap decoded=new Bitmap(source.Width,source.Height,PixelFormat.Format32bppArgb);
            try{using(Graphics g=Graphics.FromImage(decoded)){
                g.CompositingMode=System.Drawing.Drawing2D.CompositingMode.SourceCopy;
                g.DrawImageUnscaled(source,0,0);
            }return decoded;}catch{decoded.Dispose();throw;}
        }
    }
    protected override void Dispose(bool disposing){
        base.Dispose(disposing);if(disposing){foreach(Bitmap image in ownedImages)image.Dispose();ownedImages.Clear();}
    }
}
}
