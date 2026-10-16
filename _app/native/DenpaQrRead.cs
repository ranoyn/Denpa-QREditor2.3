// Project-local restricted QR reader. No third-party decoding library.
// Clean, axis-aligned byte-mode QR only. ECC is verified, not repaired.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Text;
using System.Windows.Forms;

namespace DenpaQrVerification {
public sealed class FaceImport {
    public int Game;
    public string Name;
    public string Language="JP";
    public Dictionary<string,int> Parts = new Dictionary<string,int>();
    public Dictionary<string,string> Fields = new Dictionary<string,string>();
    public Dictionary<string,int> Equipment = new Dictionary<string,int>();
    public Dictionary<string,int> Bonuses = new Dictionary<string,int>();
    public int Paint=-1,Level,Correction,Monster,Claim,Quantity,StatureValue;
    public bool Special;
    public int[] Rewards=new int[4];
    public string Memo="",Date="";
    public byte[] Plain;
}
public static partial class Core {
    static bool ReadMask(int x,int y,int m) {
        switch(m) {
        case 0:return (x+y)%2==0;case 1:return y%2==0;case 2:return x%3==0;
        case 3:return (x+y)%3==0;case 4:return (y/2+x/3)%2==0;
        case 5:return (x*y)%2+(x*y)%3==0;case 6:return ((x*y)%2+(x*y)%3)%2==0;
        case 7:return ((x+y)%2+(x*y)%3)%2==0;default:throw new ArgumentException("Mask");
        }
    }
    static int Difference(int a,int b) {int n=a^b,c=0;while(n!=0){c+=n&1;n>>=1;}return c;}
    static int ReadFormat(int bits) {
        int best=16,found=-1;
        for(int i=0;i<32;i++){int d=Difference(bits,Bch(i,10,0x537)^0x5412);if(d<best){best=d;found=i;}else if(d==best)found=-1;}
        if(best>3||found<0)throw new ArgumentException("Unreadable QR format.");return found;
    }
    static int Take(List<int> bits,ref int pos,int count) {
        if(pos+count>bits.Count)throw new ArgumentException("Truncated QR.");int n=0;
        for(int i=0;i<count;i++)n=(n<<1)|bits[pos++];return n;
    }
    static byte[] ReadMatrix(bool[,] q) {
        int size=q.GetLength(0),a=0,b=0;
        for(int i=0;i<=5;i++)if(q[8,i])a|=1<<i;
        if(q[8,7])a|=1<<6;if(q[8,8])a|=1<<7;if(q[7,8])a|=1<<8;
        for(int i=9;i<15;i++)if(q[14-i,8])a|=1<<i;
        for(int i=0;i<8;i++)if(q[size-1-i,8])b|=1<<i;
        for(int i=8;i<15;i++)if(q[8,size-15+i])b|=1<<i;
        int fa=ReadFormat(a),fb=ReadFormat(b);
        if(fa!=fb)throw new ArgumentException("Conflicting QR format copies.");
        int ec=fa>>3,mask=fa&7;Profile p;
        if(size==41&&ec==1)p=GetProfile(120);
        else if(size==41&&ec==0)p=GetProfile(106);
        else if(size==49&&ec==1)p=GetProfile(160);
        else if(size==61&&ec==1)p=GetProfile(288);
        else throw new ArgumentException("Unsupported QR version/error-correction profile.");
        int[,] used=new int[size,size];for(int y=0;y<size;y++)for(int x=0;x<size;x++)used[x,y]=-1;
        Finder(used,0,0);Finder(used,size-7,0);Finder(used,0,size-7);
        // Check all three finder patterns rather than guessing orientation.
        for(int y=0;y<size;y++)for(int x=0;x<size;x++)if(used[x,y]>=0&&q[x,y]!=(used[x,y]==1))throw new ArgumentException("Finder mismatch.");
        for(int i=8;i<size-8;i++){Set(used,i,6,true);Set(used,6,i,true);}
        foreach(int cy in p.Align)foreach(int cx in p.Align){
            if((cx<=8&&cy<=8)||(cx>=size-9&&cy<=8)||(cx<=8&&cy>=size-9))continue;
            for(int dy=-2;dy<=2;dy++)for(int dx=-2;dx<=2;dx++)Set(used,cx+dx,cy+dy,true);
        }
        Set(used,8,size-8,true);
        for(int i=0;i<=5;i++)Set(used,8,i,true);Set(used,8,7,true);Set(used,8,8,true);Set(used,7,8,true);
        for(int i=9;i<15;i++)Set(used,14-i,8,true);
        for(int i=0;i<8;i++)Set(used,size-1-i,8,true);for(int i=8;i<15;i++)Set(used,8,size-15+i,true);
        if(p.Version>=7){int ver=Bch(p.Version,12,0x1f25);for(int i=0;i<18;i++){int x=size-11+i%3,y=i/3;bool v=((ver>>i)&1)!=0;if(q[x,y]!=v||q[y,x]!=v)throw new ArgumentException("Version mismatch.");Set(used,x,y,true);Set(used,y,x,true);}}
        List<int> raw=new List<int>();bool up=true;
        for(int right=size-1;right>0;right-=2){if(right==6)right--;for(int n=0;n<size;n++){int y=up?size-1-n:n;for(int x=right;x>=right-1;x--)if(used[x,y]<0)raw.Add(q[x,y]^ReadMask(x,y,mask)?1:0);}up=!up;}
        int count=p.Data+p.Ecc*p.Blocks.Length,pos=0;int[] interleaved=new int[count];for(int i=0;i<count;i++)interleaved[i]=Take(raw,ref pos,8);
        List<int[]> blocks=new List<int[]>();List<int[]> parity=new List<int[]>();int max=0;
        foreach(int len in p.Blocks){blocks.Add(new int[len]);parity.Add(new int[p.Ecc]);max=Math.Max(max,len);}
        pos=0;for(int i=0;i<max;i++)foreach(int[] block in blocks)if(i<block.Length)block[i]=interleaved[pos++];
        for(int i=0;i<p.Ecc;i++)foreach(int[] block in parity)block[i]=interleaved[pos++];
        List<int> dataBits=new List<int>();for(int i=0;i<blocks.Count;i++){
            int[] check=Ecc(blocks[i],p.Ecc);for(int j=0;j<check.Length;j++)if(check[j]!=parity[i][j])throw new ArgumentException("QR has damaged/unclear cells. This simple reader does not repair errors.");
            foreach(int value in blocks[i])AppendBits(dataBits,value,8);
        }
        pos=0;int mode=Take(dataBits,ref pos,4);
        if(mode==7){int eci=Take(dataBits,ref pos,8);if((eci&128)!=0)throw new ArgumentException("Unsupported ECI.");mode=Take(dataBits,ref pos,4);}
        if(mode!=4)throw new ArgumentException("Expected binary byte-mode QR.");
        int length=Take(dataBits,ref pos,p.Version<10?8:16);
        if(length!=88&&length!=106&&length!=120&&length!=160&&length!=288)throw new ArgumentException("Not a supported Denpa QR length.");
        byte[] payload=new byte[length];for(int i=0;i<length;i++)payload[i]=(byte)Take(dataBits,ref pos,8);return payload;
    }
    // The caller supplies a tight QR-only rectangle, possibly with its white margin.
    public static byte[] ReadQrImage(Bitmap image,Rectangle crop) {
        if(image.Width>4096||image.Height>4096)throw new ArgumentException("Image too large (maximum 4096 pixels per side).");
        if(crop.Width<37||crop.Height<37||crop.Width*crop.Height>2097152||!new Rectangle(0,0,image.Width,image.Height).Contains(crop))throw new ArgumentException("Select the QR area (maximum 2 million pixels).");
        int left=crop.Right,top=crop.Bottom,right=-1,bottom=-1;
        for(int y=crop.Top;y<crop.Bottom;y++)for(int x=crop.Left;x<crop.Right;x++){
            Color c=image.GetPixel(x,y);if(c.A>127&&(c.R*299+c.G*587+c.B*114)<128000){left=Math.Min(left,x);right=Math.Max(right,x);top=Math.Min(top,y);bottom=Math.Max(bottom,y);}
        }
        int w=right-left+1,h=bottom-top+1;
        if(w<37||h<37||Math.Abs(w-h)>Math.Max(w,h)*0.03)throw new ArgumentException("Select only the square QR and its white margin.");
        foreach(int size in new int[]{41,49,61}){
            if(w<size||h<size)continue;bool[,] q=new bool[size,size];
            for(int y=0;y<size;y++)for(int x=0;x<size;x++){
                Color c=image.GetPixel(left+(int)((x+0.5)*w/size),top+(int)((y+0.5)*h/size));q[x,y]=c.R*299+c.G*587+c.B*114<128000;
            }
            for(int turn=0;turn<4;turn++){
                try {return ReadMatrix(q);}catch(ArgumentException){}
                bool[,] next=new bool[size,size];for(int y=0;y<size;y++)for(int x=0;x<size;x++)next[x,y]=q[y,size-1-x];q=next;
            }
        }
        throw new ArgumentException("Cannot read this QR. Select a tight QR-only area of a clear screenshot or editor image. Photos, damaged cells and some QR formats are not supported.");
    }
    static int FaceBits(byte[] b,int offset,int bit,int width){int n=0;for(int i=0;i<width;i++)n|=((b[offset+(bit+i)/8]>>((bit+i)%8))&1)<<i;return n;}
    public static FaceImport ReadFace(byte[] payload) {
        FaceImport result=new FaceImport();byte[] b;
        if(payload.Length==106){
            b=Decrypt1(payload);string header=Encoding.ASCII.GetString(b,0,4);
            if(header!="bX80"&&header!="Ah43"&&header!="j3Zw")throw new ArgumentException("Not an RPG1 QR.");
            result.Game=1;result.Language=header=="Ah43"?"NA":header=="j3Zw"?"EU":"JP";
            result.Name=Encoding.Unicode.GetString(b,26,header=="bX80"?12:24).Split('\0')[0];
            int face=FaceBits(b,10,5,6),gate=FaceBits(b,20,5,7)%100;
            int hair=gate>=90?face%23+1:0;
            int[] contour={0,0,0,4,0,7,6,1,0,2,0,7,2,7,4,1,3,1,5,3,0,8,8,0};
            result.Parts["hair"]=hair;result.Parts["contour"]=hair==0?face%9:contour[hair];
            result.Parts["brow"]=FaceBits(b,14,6,5)%8;result.Parts["eyes"]=FaceBits(b,12,5,6)%32;
            result.Parts["nose"]=FaceBits(b,13,3,5)%16;result.Parts["mouth"]=FaceBits(b,14,0,6)%32;
            result.Parts["cheeks"]=FaceBits(b,22,0,7)%100>=90?FaceBits(b,15,3,5)%7+1:0;
            result.Parts["glasses"]=FaceBits(b,22,7,7)%100>=90?FaceBits(b,16,0,5)%15+1:0;
            int lo=FaceBits(b,11,3,5)%3,hi=FaceBits(b,23,6,7)%100;
            result.Parts["skin"]=(hi<90?new int[]{0,1,5}:new int[]{4,2,3})[lo];
            result.Parts["hairColor"]=FaceBits(b,12,0,5)%12;
        }else{
            result.Game=(payload.Length==120||payload.Length==288)?2:3;
            b=Plain(result.Game,Hex(payload));Validate(b);
            string magic=Encoding.ASCII.GetString(b,0,4);
            if(result.Game==2&&magic!="1_2D"&&magic!="PS2D")throw new ArgumentException("Not an RPG2 QR.");
            if(result.Game==3&&magic!="1_3D"&&magic!="2S3D")throw new ArgumentException("Not an RPG3 QR.");
            result.Name=Name(b,result.Game);
            if(result.Game==2)result.Language=b[6]==2?"NA":b[6]==3?"EU":"JP";
            else {int region=(int)Read(b,0x50,2);if(region!=1&&region!=2&&region!=4)throw new ArgumentException("Multi-region QR is not supported by this simple importer.");result.Language=region==2?"NA":region==4?"EU":"JP";}
            string[] keys={"contour","hair","brow","eyes","nose","mouth","cheeks","glasses","skin","hairColor"};
            int[] at=result.Game==3?new int[]{34,35,36,37,38,39,40,41,45,46}:new int[]{101,102,104,105,106,107,108,109,101,103};
            for(int i=0;i<keys.Length;i++)result.Parts[keys[i]]=result.Game==2&&keys[i]=="contour"?b[101]&15:result.Game==2&&keys[i]=="skin"?b[101]>>4:b[at[i]];
        }
        result.Plain=(byte[])b.Clone();result.Special=b.Length==160||b.Length==288;
        if(result.Game!=1){
            foreach(KeyValuePair<string,int> entry in result.Game==2?map2:map3) {
                if(entry.Key=="--identity-byte"||entry.Key=="--face-style"||entry.Key.StartsWith("--special-"))continue;
                result.Fields[entry.Key]=b[entry.Value].ToString("X2");
            }
            if(result.Game==2){result.Fields["--face-image"]=(b[101]>>4).ToString("X2");result.Fields["--face-shape"]=(b[101]&15).ToString("X2");}
            result.Level=result.Game==2?b[0x38]:(int)Read(b,0x36,2);
            result.Paint=result.Game==2?(b[15]==0?-1:b[15]-1):((b[47]&1)==0?-1:b[47]>>1);
            if(result.Game==2||result.Special)result.Memo=Encoding.Unicode.GetString(b,result.Game==2?16:120,32).Split('\0')[0];
            try{result.Date=(result.Game==2?new DateTime(2000,1,1).AddMilliseconds((long)Read(b,48,6)):new DateTime(1999,1,1).AddSeconds((long)Read(b,4,4))).ToString("yyyy-MM-dd");}catch(ArgumentOutOfRangeException){}
            string[] slots={"neck","arm","back","feet","clothing"};int[] shifts={0,10,30,20,40};
            for(int i=0;i<5;i++){int id=result.Game==2?FaceBits(b,58,shifts[i],10):(int)Read(b,68+(i==2?3:i==3?2:i)*2,2);if(result.Game==2&&i==4&&id!=0)id+=0x400;result.Equipment[slots[i]]=id;}
            if(result.Game==3){
                result.Correction=b[53]>>4;result.Monster=b[52];
                foreach(KeyValuePair<string,int> entry in stats)result.Bonuses[entry.Key]=(int)Read(b,entry.Value,2);
                if(result.Special){result.Claim=b[84];result.Quantity=b[85];for(int i=0;i<4;i++)result.Rewards[i]=(int)Read(b,86+i*2,2);}
            }else if(result.Special)result.Claim=(int)Read(b,110,2);
        }else{
            result.StatureValue=FaceBits(b,8,6,5)|(FaceBits(b,17,0,4)<<5);
            int antLow=FaceBits(b,8,0,6),antGate=FaceBits(b,19,6,7)%100;
            result.Parts["antenna"]=antGate<70?0:antGate<90?antLow%12+1:antGate<93?antLow%12+13:antLow%21+25;
            int headLo=FaceBits(b,10,0,5),headGate=FaceBits(b,18,7,7)%100;
            result.Parts["head"]=headGate<80?headLo%11:headGate<95?headLo%7+11:headLo%6+18;
            int colorLo=FaceBits(b,9,3,5),colorGate=FaceBits(b,18,0,7)%100,ant=result.Parts["antenna"];
            if(colorGate>=95)result.Parts["body"]=colorLo%15+7;
            else {
                int special=ant>=7&&ant<=12?ant-7:ant>=19&&ant<=24?ant-19:-1;
                if(special<0)result.Parts["body"]=colorGate<40?0:colorLo%7+1;
                else {int[][] maps={new int[]{1,3,4,5,6,0,1},new int[]{1,2,4,5,6,0,1},new int[]{1,2,3,5,6,0,1},new int[]{1,2,3,4,6,0,1},new int[]{1,2,3,4,5,0,1},new int[]{2,3,4,5,6,0,1}};result.Parts["body"]=colorGate<40?new int[]{2,3,4,5,6,1}[special]:maps[special][colorLo%7];}
            }
        }
        if(result.Name.Length==0)throw new ArgumentException("QR name is empty.");
        return result;
    }
}
// Restricted selector: it does not scan the desktop, camera, or any other file.
public sealed class QrCropForm : Form {
    readonly PictureBox picture=new PictureBox();readonly Bitmap source;
    Point start;Rectangle selection;bool dragging;
    public Rectangle Crop;
    Rectangle Content {
        get {double scale=Math.Min((double)picture.ClientSize.Width/source.Width,(double)picture.ClientSize.Height/source.Height);int w=(int)Math.Round(source.Width*scale),h=(int)Math.Round(source.Height*scale);return new Rectangle((picture.ClientSize.Width-w)/2,(picture.ClientSize.Height-h)/2,w,h);}
    }
    public QrCropForm(Bitmap image,bool english) {
        source=image;Text=english?"Select QR area":"QRの範囲を選択";ClientSize=new Size(740,600);StartPosition=FormStartPosition.CenterParent;FormBorderStyle=FormBorderStyle.FixedDialog;MaximizeBox=false;MinimizeBox=false;
        Label note=new Label();note.Text=english?"Drag around ONLY the QR, including its white margin. Screenshots/editor images only; no photos.":"QRと白い余白だけを囲むようにドラッグしてください。ゲーム内スクショ・QR単体・Editor画像専用です。";note.SetBounds(15,10,710,45);Controls.Add(note);
        picture.SetBounds(15,60,710,470);picture.Image=image;picture.SizeMode=PictureBoxSizeMode.Zoom;picture.BackColor=Color.Gainsboro;Controls.Add(picture);
        picture.MouseDown+=delegate(object s,MouseEventArgs e){if(e.Button!=MouseButtons.Left)return;start=e.Location;dragging=true;selection=Rectangle.Empty;};
        picture.MouseMove+=delegate(object s,MouseEventArgs e){if(!dragging)return;selection=Rectangle.Intersect(Content,Rectangle.FromLTRB(Math.Min(start.X,e.X),Math.Min(start.Y,e.Y),Math.Max(start.X,e.X),Math.Max(start.Y,e.Y)));picture.Invalidate();};
        picture.MouseUp+=delegate{dragging=false;};
        picture.Paint+=delegate(object s,PaintEventArgs e){if(selection.Width>0)using(Pen p=new Pen(Color.Red,2))e.Graphics.DrawRectangle(p,selection);};
        Button all=new Button();all.Text=english?"Whole image (QR only)":"画像全体（QR単体用）";all.SetBounds(15,548,235,34);all.Click+=delegate{selection=Content;picture.Invalidate();};Controls.Add(all);
        Button ok=new Button();ok.Text=english?"Read QR":"この範囲を読み取る";ok.SetBounds(330,548,195,34);Controls.Add(ok);
        ok.Click+=delegate{Rectangle r=Content;if(selection.Width<10||selection.Height<10)return;int x=Math.Max(0,(selection.Left-r.Left)*source.Width/r.Width),y=Math.Max(0,(selection.Top-r.Top)*source.Height/r.Height);int right=Math.Min(source.Width,(int)Math.Ceiling((double)(selection.Right-r.Left)*source.Width/r.Width)),bottom=Math.Min(source.Height,(int)Math.Ceiling((double)(selection.Bottom-r.Top)*source.Height/r.Height));Crop=Rectangle.FromLTRB(x,y,right,bottom);DialogResult=DialogResult.OK;};
        Button cancel=new Button();cancel.Text=english?"Cancel":"キャンセル";cancel.SetBounds(540,548,185,34);cancel.DialogResult=DialogResult.Cancel;Controls.Add(cancel);CancelButton=cancel;
    }
}
}
