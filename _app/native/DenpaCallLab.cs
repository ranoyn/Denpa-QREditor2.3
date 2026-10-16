using System;
using System.Collections.Generic;
namespace DenpaQrVerification {
public static partial class Core {
    // Compact compatibility parameters, not an embedded game data file.
    static readonly int[][] labWeights={
        new[]{30,30,40,50,10,35,5},new[]{20,40,40,50,10,35,5},new[]{20,35,50,65,5,25,5},new[]{15,35,50,65,5,25,5},new[]{10,50,40,65,5,25,5},
        new[]{30,30,40,50,10,35,5},new[]{30,30,40,50,10,35,5},new[]{30,30,40,50,10,35,5},new[]{30,30,40,50,10,35,5},new[]{30,30,40,50,10,35,5},
        new[]{20,30,40,50,20,35,5},new[]{20,30,40,50,20,25,5},new[]{20,30,40,50,20,25,5},new[]{20,30,40,50,20,25,5},new[]{20,30,40,50,20,25,5},
        new[]{20,30,50,50,20,25,5},new[]{20,30,50,40,20,35,5},new[]{20,30,50,40,20,35,5},new[]{20,30,50,40,20,35,5},new[]{20,30,50,40,20,35,5},
        new[]{10,30,60,40,20,35,5},new[]{10,30,60,40,20,35,5},new[]{10,30,60,40,20,35,5},new[]{10,30,60,40,20,35,5},new[]{10,30,60,40,20,35,5},
        new[]{5,15,80,40,5,50,5},new[]{5,25,70,30,20,45,5},new[]{10,20,70,30,25,45,5},new[]{10,30,60,35,25,35,5},new[]{10,40,50,35,25,35,5}
    };
    static readonly int[] labNext={0,0,0,0,0,6,68,8,68,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,25,0,27,0,29,0,31,0,0,0,0,0,0,0,39,0,41,0,43,0,45,46,0,48,49,0,51,52,0,54,55,0,57,58,0,60,61,0,63,64,0,66,67,0};
    static readonly int[] labStats1={384,320,321,322,385,325,3,0,1,2,326,324,9,10,6,7,11,327,8,330,328,329,333,387,386,331,332};
    static int LabBits(byte[] b,int at,int bit,int width){int n=0;for(int i=0;i<width;i++){int p=bit+i;n|=((b[at+(p>>3)]>>(p&7))&1)<<i;}return n;}
    public static int CallLabNext(int antenna){return antenna>=0&&antenna<labNext.Length?labNext[antenna]:-1;}
    public static int CallLabBody1(byte[] b){
        int group=LabBits(b,16,5,7)%100;
        int[] choices=group<75?new[]{6,7,8,11,12,13,16,17,18,21,22,23}:group<95?new[]{1,2,3,5,9,10,14,15,19,20,24,26,27,28}:new[]{0,4,25,29};
        return choices[LabBits(b,8,6,5)%choices.Length];
    }
    public static int CallLabBodyFromStature1(int index){if(index<0||index>=labStats1.Length)return -1;byte[] b=Baseline1();Bits(b,8,6,5,labStats1[index]&31);Bits(b,17,0,4,labStats1[index]>>5);return CallLabBody1(b);}
    static int LabRaw(int game,int body,int n){
        if(body<0||body>=labWeights.Length)throw new ArgumentException("Unsupported body type.");
        int start=game==1?0:3,count=game==1?3:4,total=0;for(int i=0;i<count;i++)total+=labWeights[body][start+i];
        int value=n%total;int[] codes=game==1?new[]{3,4,1}:new[]{2,5,6,7};
        for(int i=0;i<count;i++){int w=labWeights[body][start+i];if(value<=w)return codes[i];value-=w;}return 0;
    }
    static int LabFinal(int code,int antenna){if(antenna==0&&(code==2||code==7||code==8))return 1;if(code==7&&CallLabNext(antenna)==0)return 8;return code;}
    public static int[] CallLabChoices(int game,int body,int antenna,int personality){
        if(body<0||body>=30||(game==2&&(antenna<0||antenna>67||personality==0x64||personality==0x65)))return new int[0];
        List<int> codes=new List<int>();for(int n=0;n<256;n++){int code=LabRaw(game,body,n);if(game==2)code=LabFinal(code,antenna);if(!codes.Contains(code))codes.Add(code);}return codes.ToArray();
    }
    public static void CallLabAdjust1(byte[] plain,int code){
        int body=CallLabBody1(plain),original=LabBits(plain,22,21,11);if(LabRaw(1,body,original)==code)return;
        for(int n=0;n<2048;n++)if(LabRaw(1,body,n)==code){Bits(plain,22,21,11,n);return;}throw new ArgumentException("Unavailable RPG3 ability.");
    }
    public static void CallLabAdjust2(byte[] plain,int code){
        int body=plain[0x64],antenna=plain[0x61],personality=plain[0x60];
        if(Array.IndexOf(CallLabChoices(2,body,antenna,personality),code)<0)throw new ArgumentException("Unavailable RPG3 ability or character cannot be called.");
        int other=0;for(int i=0x5e;i<0x6e;i++)if(i!=0x5f)other+=plain[i];
        if(LabFinal(LabRaw(2,body,other+plain[0x5f]),antenna)==code)return;
        for(int n=0;n<256;n++)if(LabFinal(LabRaw(2,body,other+n),antenna)==code){plain[0x5f]=(byte)n;return;}throw new ArgumentException("Unavailable RPG3 ability.");
    }
}
}
