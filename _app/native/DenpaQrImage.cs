// QR matrix generation ported from QREditor's existing byte-mode encoder.
// PNG compression can differ from Node's output; every black/white pixel must match.
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;
using System.Collections.Generic;

namespace DenpaQrVerification {
public static partial class Core {
    sealed class Profile {
        public int Version,Size,Data,Ecc,Mask,Ec,Remaining; public int[] Blocks,Align;
        public Profile(int v,int size,int data,int ecc,int mask,int ec,int rem,int[] blocks,int[] align){Version=v;Size=size;Data=data;Ecc=ecc;Mask=mask;Ec=ec;Remaining=rem;Blocks=blocks;Align=align;}
    }
    static Profile GetProfile(int bytes) {
        switch(bytes){
            case 88: case 120:return new Profile(6,41,136,18,4,1,7,new int[]{68,68},new int[]{6,34});
            case 106:return new Profile(6,41,108,16,0,0,7,new int[]{27,27,27,27},new int[]{6,34});
            case 160:return new Profile(8,49,194,24,6,1,0,new int[]{97,97},new int[]{6,24,42});
            case 288:return new Profile(11,61,324,20,4,1,0,new int[]{81,81,81,81},new int[]{6,30,54});
            default:throw new ArgumentException("Unsupported QR size.");
        }
    }
    static readonly int[] exp=new int[512],log=new int[256];
    static Core() {int x=1;for(int i=0;i<255;i++){exp[i]=x;log[x]=i;x<<=1;if((x&256)!=0)x^=0x11d;}for(int i=255;i<512;i++)exp[i]=exp[i-255];}
    static int Mul(int a,int b) {return a==0||b==0?0:exp[log[a]+log[b]];}
    static int[] Generator(int degree) {
        int[] poly={1};for(int i=0;i<degree;i++){int[] next=new int[poly.Length+1];for(int j=0;j<poly.Length;j++){next[j]^=poly[j];next[j+1]^=Mul(poly[j],exp[i]);}poly=next;}return poly;
    }
    static int[] Ecc(int[] data,int degree) {
        int[] gen=Generator(degree),rem=new int[degree];foreach(int value in data){int factor=value^rem[0];Array.Copy(rem,1,rem,0,degree-1);rem[degree-1]=0;for(int i=0;i<degree;i++)rem[i]^=Mul(gen[i+1],factor);}return rem;
    }
    static void AppendBits(List<int> bits,int value,int width) {for(int i=width-1;i>=0;i--)bits.Add((value>>i)&1);}
    static int[] Codewords(byte[] payload,Profile p) {
        List<int> bits=new List<int>();AppendBits(bits,4,4);AppendBits(bits,payload.Length,p.Version<10?8:16);foreach(byte n in payload)AppendBits(bits,n,8);
        for(int i=0;i<4&&bits.Count<p.Data*8;i++)bits.Add(0);while(bits.Count%8!=0)bits.Add(0);
        List<int> data=new List<int>();for(int i=0;i<bits.Count;i+=8){int n=0;for(int j=0;j<8;j++)n=(n<<1)|bits[i+j];data.Add(n);}for(int toggle=0;data.Count<p.Data;toggle^=1)data.Add(toggle==0?0xec:0x11);
        if(data.Count!=p.Data)throw new ArgumentException("QR data exceeds capacity.");
        List<int[]> blocks=new List<int[]>(),parity=new List<int[]>();int at=0,longest=0;
        foreach(int length in p.Blocks){int[] b=data.GetRange(at,length).ToArray();blocks.Add(b);parity.Add(Ecc(b,p.Ecc));at+=length;longest=Math.Max(longest,length);}
        if(at!=data.Count)throw new InvalidOperationException("Invalid block layout.");
        List<int> result=new List<int>();for(int i=0;i<longest;i++)foreach(int[] b in blocks)if(i<b.Length)result.Add(b[i]);for(int i=0;i<p.Ecc;i++)foreach(int[] b in parity)result.Add(b[i]);return result.ToArray();
    }
    static void Set(int[,] m,int x,int y,bool value) {if(x>=0&&y>=0&&x<m.GetLength(0)&&y<m.GetLength(1))m[x,y]=value?1:0;}
    static void Finder(int[,] m,int x,int y) {
        for(int dy=-1;dy<=7;dy++)for(int dx=-1;dx<=7;dx++){bool edge=dx==-1||dx==7||dy==-1||dy==7;bool black=!edge&&(dx==0||dx==6||dy==0||dy==6||(dx>=2&&dx<=4&&dy>=2&&dy<=4));Set(m,x+dx,y+dy,black);}
    }
    static int BitLength(int n) {int bits=0;while(n!=0){bits++;n>>=1;}return bits;}
    static int Bch(int value,int shift,int polynomial) {int v=value<<shift;while(BitLength(v)>=BitLength(polynomial))v^=polynomial<<(BitLength(v)-BitLength(polynomial));return (value<<shift)|v;}
    static bool Mask(int x,int y,int mask) {
        if(mask==0)return (x+y)%2==0;if(mask==4)return (y/2+x/3)%2==0;if(mask==6)return ((x*y)%2+(x*y)%3)%2==0;throw new ArgumentException("Unsupported mask.");
    }
    public static bool[,] Modules(byte[] payload) {
        Profile p=GetProfile(payload.Length);int size=p.Size;int[,] m=new int[size,size];for(int y=0;y<size;y++)for(int x=0;x<size;x++)m[x,y]=-1;
        Finder(m,0,0);Finder(m,size-7,0);Finder(m,0,size-7);
        for(int i=8;i<size-8;i++){Set(m,i,6,i%2==0);Set(m,6,i,i%2==0);}
        foreach(int cy in p.Align)foreach(int cx in p.Align){if((cx<=8&&cy<=8)||(cx>=size-9&&cy<=8)||(cx<=8&&cy>=size-9))continue;for(int dy=-2;dy<=2;dy++)for(int dx=-2;dx<=2;dx++)Set(m,cx+dx,cy+dy,Math.Max(Math.Abs(dx),Math.Abs(dy))!=1);}
        Set(m,8,size-8,true);int fmt=Bch((p.Ec<<3)|p.Mask,10,0x537)^0x5412;
        for(int i=0;i<=5;i++)Set(m,8,i,((fmt>>i)&1)!=0);Set(m,8,7,((fmt>>6)&1)!=0);Set(m,8,8,((fmt>>7)&1)!=0);Set(m,7,8,((fmt>>8)&1)!=0);
        for(int i=9;i<15;i++)Set(m,14-i,8,((fmt>>i)&1)!=0);for(int i=0;i<8;i++)Set(m,size-1-i,8,((fmt>>i)&1)!=0);for(int i=8;i<15;i++)Set(m,8,size-15+i,((fmt>>i)&1)!=0);
        if(p.Version>=7){int v=Bch(p.Version,12,0x1f25);for(int i=0;i<18;i++){bool b=((v>>i)&1)!=0;int a=size-11+i%3,c=i/3;Set(m,a,c,b);Set(m,c,a,b);}}
        List<int> bits=new List<int>();foreach(int n in Codewords(payload,p))AppendBits(bits,n,8);
        int cursor=0;bool upward=true;for(int right=size-1;right>0;right-=2){if(right==6)right--;for(int n=0;n<size;n++){int y=upward?size-1-n:n;for(int x=right;x>=right-1;x--)if(m[x,y]<0){int bit=cursor<bits.Count?bits[cursor]:0;cursor++;Set(m,x,y,(bit!=0)^Mask(x,y,p.Mask));}}upward=!upward;}
        if(cursor!=bits.Count+p.Remaining)throw new InvalidOperationException("QR bit layout mismatch.");bool[,] output=new bool[size,size];for(int y=0;y<size;y++)for(int x=0;x<size;x++)output[x,y]=m[x,y]==1;return output;
    }
    public static Bitmap Bitmap(byte[] payload) {
        bool[,] modules=Modules(payload);int size=modules.GetLength(0),scale=8,quiet=4,width=(size+quiet*2)*scale;
        Bitmap bitmap=new Bitmap(width,width,PixelFormat.Format24bppRgb);
        using(Graphics g=Graphics.FromImage(bitmap)){g.Clear(Color.White);for(int y=0;y<size;y++)for(int x=0;x<size;x++)if(modules[x,y])g.FillRectangle(Brushes.Black,(x+quiet)*scale,(y+quiet)*scale,scale,scale);}return bitmap;
    }
    public static void Render(byte[] payload,string output) {using(Bitmap b=Bitmap(payload))using(FileStream f=new FileStream(output,FileMode.CreateNew,FileAccess.Write))b.Save(f,ImageFormat.Png);}
}
}
