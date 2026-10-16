param([string]$AssetRoot=(Join-Path $PSScriptRoot '../_app/assets/rpg3-2d'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
public static class DenpaPartsAtlasBuilder {
 static Bitmap Load(string path,string folder){
  if(!File.Exists(path))return null;
  using(Bitmap src=new Bitmap(path))using(Bitmap normalized=new Bitmap(src.Width,src.Height,PixelFormat.Format32bppArgb)){
   using(Graphics g=Graphics.FromImage(normalized))using(ImageAttributes a=new ImageAttributes()){
    ColorMatrix m=new ColorMatrix();
    // Hair artwork uses its original white fill and black outlines.
    if(folder=="outlines"){m.Matrix00=255/248f;m.Matrix11=190/219f;m.Matrix22=170/199f;}
    a.SetColorMatrix(m);g.DrawImage(src,new Rectangle(0,0,src.Width,src.Height),0,0,src.Width,src.Height,GraphicsUnit.Pixel,a);
   }
   int l=src.Width,t=src.Height,r=-1,b=-1;
   BitmapData data=normalized.LockBits(new Rectangle(0,0,src.Width,src.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
   try{byte[] row=new byte[src.Width*4];for(int y=0;y<src.Height;y++){
    Marshal.Copy(IntPtr.Add(data.Scan0,y*data.Stride),row,0,row.Length);
    for(int x=0;x<src.Width;x++){if(row[x*4+3]<12)continue;l=Math.Min(l,x);t=Math.Min(t,y);r=Math.Max(r,x);b=Math.Max(b,y);}
   }}finally{normalized.UnlockBits(data);}
   return r<l?null:normalized.Clone(new Rectangle(l,t,r-l+1,b-t+1),PixelFormat.Format32bppArgb);
  }
 }
 public static int Build(string root){
  string[] folders={"heads","hairs","outlines","brows","eyes","noses","mouths","cheeks"};int max=0,count=0;
  foreach(string folder in folders)foreach(string file in Directory.GetFiles(Path.Combine(root,folder),"*.png")){int code;if(Int32.TryParse(Path.GetFileNameWithoutExtension(file),out code)&&code>=0&&code<=255)max=Math.Max(max,code);}
  StringBuilder index=new StringBuilder("DENPA_PARTS_ATLAS_1\t"+(max+1)+"\n");
  using(Bitmap atlas=new Bitmap(2048,(max+1)*172,PixelFormat.Format32bppArgb))using(Graphics g=Graphics.FromImage(atlas)){
   g.Clear(Color.Transparent);g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.PixelOffsetMode=PixelOffsetMode.HighQuality;
   for(int row=0;row<=max;row++)for(int col=0;col<folders.Length;col++){
    string path=Path.Combine(Path.Combine(root,folders[col]),row.ToString("D2")+".png");
    if(col==1&&row==28){string common=Path.Combine(root,"hairs-common/28.png");if(File.Exists(common))path=common;}
    using(Bitmap image=Load(path,folders[col])){
     if(image==null)continue;double scale=Math.Min(216.0/image.Width,132.0/image.Height);
     int w=Math.Max(1,(int)Math.Round(image.Width*scale)),h=Math.Max(1,(int)Math.Round(image.Height*scale));
     int x=col*256+(256-w)/2,y=row*172+(172-h)/2;
     g.DrawImage(image,new Rectangle(x,y,w,h));
     index.AppendFormat(System.Globalization.CultureInfo.InvariantCulture,"{0}\t{1}\t{2}\t{3}\t{4}\t{5}\n",row,col,x,y,w,h);count++;
    }
   }
   atlas.Save(Path.Combine(root,"face-parts-atlas.png"),ImageFormat.Png);
  }
  File.WriteAllText(Path.Combine(root,"face-parts-atlas.tsv"),index.ToString(),new UTF8Encoding(false));return count;
 }
}
'@ -ReferencedAssemblies System.Drawing
[DenpaPartsAtlasBuilder]::Build([IO.Path]::GetFullPath($AssetRoot))
