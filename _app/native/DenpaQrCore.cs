// QREditor verification backend. Port of this project's JS compatibility code.
// This language change does not change provenance or grant redistribution rights.
// RPG2/3 game-specific key and observed record metadata are unchanged.
// RPG1 encoding uses hardware-tested zero parameters instead of a copied table.
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Globalization;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;

namespace DenpaQrVerification {
public static partial class Core {
    static string root;
    static Blowfish cipher;
    static readonly object gate = new object();
    static readonly JavaScriptSerializer json = new JavaScriptSerializer();
    public static void Initialize(string applicationRoot) {
        lock (gate) {
            string path = Path.GetFullPath(applicationRoot);
            if (root != path) { root = path; cipher = null; antennaEvolution3 = null; }
        }
    }
    static Blowfish Cipher() {
        lock (gate) {
            if (cipher == null) cipher = new Blowfish(Convert.FromBase64String(File.ReadAllText(Path.Combine(root,"data/blowfish-initial.b64")).Trim()));
            return cipher;
        }
    }
    public static string Hex(byte[] data) { return BitConverter.ToString(data).Replace("-","").ToLowerInvariant(); }
    public static byte[] Bytes(string text, params int[] lengths) {
        string s = Regex.Replace(text ?? "",@"\s","");
        if (!Regex.IsMatch(s,@"\A[0-9a-fA-F]+\z") || s.Length % 2 != 0) throw new ArgumentException("Invalid hexadecimal data.");
        if (lengths.Length > 0 && Array.IndexOf(lengths,s.Length/2) < 0) throw new ArgumentException("Invalid payload length.");
        byte[] b = new byte[s.Length/2];
        for (int i=0;i<b.Length;i++) b[i]=Convert.ToByte(s.Substring(i*2,2),16);
        return b;
    }
    static int Number(string s,int digits,bool prefix) {
        string text = prefix ? Regex.Replace(s,@"\A0x","",RegexOptions.IgnoreCase) : s;
        if (!Regex.IsMatch(text,@"\A[0-9a-fA-F]{1,"+digits+@"}\z")) throw new ArgumentException("Invalid hexadecimal value: "+s);
        return Convert.ToInt32(text,16);
    }
    static int Decimal(string s,int digits,int max) {
        if (!Regex.IsMatch(s,@"\A[0-9]{1,"+digits+@"}\z")) throw new ArgumentException("Invalid decimal value: "+s);
        int n=int.Parse(s,CultureInfo.InvariantCulture); if(n>max)throw new ArgumentException("Value out of range: "+s); return n;
    }
    static ulong Read(byte[] b,int at,int width) { ulong n=0;for(int i=0;i<width;i++)n|=(ulong)b[at+i]<<(i*8);return n; }
    static void Write(byte[] b,int at,int width,ulong n) {
        if(width<8 && n>=(1UL<<(width*8)))throw new ArgumentException("Value does not fit field.");
        for(int i=0;i<width;i++)b[at+i]=(byte)(n>>(i*8));
    }
    static void Text(byte[] b,int at,string s) { for(int i=0;i<s.Length;i++){b[at+i*2]=(byte)s[i];b[at+i*2+1]=(byte)(s[i]>>8);} }
    static void Ascii(byte[] b,int at,string s) { Encoding.ASCII.GetBytes(s).CopyTo(b,at); }
    static void Bits(byte[] b,int at,int bit,int width,int value) {
        if(value<0 || value>=(1<<width))throw new ArgumentException("Packed value out of range.");
        for(int i=0;i<width;i++){int pos=bit+i,index=at+(pos>>3),mask=1<<(pos&7);b[index]=(byte)((b[index]&~mask)|(((value>>i)&1)!=0?mask:0));}
    }
    public static uint Crc(byte[] b,int count) {
        unchecked { uint crc=0xffffffff;
            for(int i=0;i<count;i++){crc^=(uint)b[i]<<24;for(int j=0;j<8;j++)crc=(crc&0x80000000)!=0?(crc<<1)^0x04c11db7:crc<<1;}
            return crc^0xffffffff;
        }
    }
    static void Finish(byte[] b) { Write(b,b.Length-4,4,Crc(b,b.Length-4)); }
    static void Validate(byte[] b) { if(Read(b,b.Length-4,4)!=Crc(b,b.Length-4))throw new ArgumentException("Carrier CRC is invalid."); }
    static Dictionary<string,int> Map(params object[] pairs) {
        Dictionary<string,int> map=new Dictionary<string,int>();for(int i=0;i<pairs.Length;i+=2)map.Add((string)pairs[i],(int)pairs[i+1]);return map;
    }
    static readonly Dictionary<string,int> map3=Map("--special-identity-byte",7,"--antenna-appearance",0x20,"--head-shape",0x21,"--contour",0x22,"--hair",0x23,"--eyebrow",0x24,"--eyes",0x25,"--nose",0x26,"--mouth",0x27,"--cheeks",0x28,"--glasses",0x29,"--stature",0x2a,"--body-color",0x2c,"--skin-color",0x2d,"--hair-color",0x2e,"--personality",0x31,"--antenna",0x32,"--captured-monster",0x34,"--special-code",0x54,"--special-parameter",0x55);
    static readonly Dictionary<string,int> map2=Map("--identity-byte",8,"--personality",0x60,"--antenna",0x61,"--body-color",0x62,"--head-shape",0x63,"--stature",0x64,"--face-style",0x65,"--hair",0x66,"--hair-color",0x67,"--eyebrow",0x68,"--eyes",0x69,"--nose",0x6a,"--mouth",0x6b,"--cheeks",0x6c,"--glasses",0x6d);
    static readonly Dictionary<string,int> stats=Map("--hp-bonus",0x38,"--ap-bonus",0x3a,"--strength-bonus",0x3c,"--defense-bonus",0x3e,"--speed-bonus",0x40,"--evade-bonus",0x42);
    static Dictionary<string,object> Template(int game,string file) {
        return json.Deserialize<Dictionary<string,object>>(File.ReadAllText(Path.Combine(root,"Denpatemplates/RPG"+game+"/"+file),Encoding.UTF8));
    }
    static string Str(Dictionary<string,object> t,string key) { return Convert.ToString(t[key],CultureInfo.InvariantCulture); }
    static void Name(byte[] b,int game,string name) {
        bool overseas=game==2&&(b[6]==2||b[6]==3);
        int limit=game==2&&!overseas?7:11;
        if(name.Length==0||name.Length>limit)throw new ArgumentException("Name must be 1 to "+limit+" UTF-16 code units for this QR region.");
        int at=game==2?0x46:8;
        // Overseas RPG2 names use the tail up to 0x5D; never touch 0x5E attributes.
        // JP keeps its shorter field and preserves the trailing auxiliary bytes.
        Array.Clear(b,at,game==2?(overseas?24:16):8); Text(b,at,name); Write(b,at+name.Length*2,2,0);
        if(game==3&&b.Length==160){Array.Clear(b,0x60,32);Text(b,0x60,name);Write(b,0x60+name.Length*2,2,0);}
    }
    static string Name(byte[] b,int game) {
        int at=game==2?0x46:8,count=game==2&&b[6]!=2&&b[6]!=3?8:12;
        StringBuilder s=new StringBuilder();for(int i=0;i<count;i++){char c=(char)Read(b,at+2*i,2);if(c==0)break;s.Append(c);}return s.ToString();
    }
    static void Date(byte[] b,int game,string value) {
        DateTime date;
        if(!Regex.IsMatch(value,@"\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z")||!DateTime.TryParseExact(value,"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out date)||date.Year<100)throw new ArgumentException("Invalid QR date: "+value);
        DateTime epoch=new DateTime(game==2?2000:1999,1,1);
        int at=game==2?0x30:4,width=game==2?6:4;
        ulong scale=game==2?86400000UL:86400UL;
        long stamp=(game==2?(long)(date-epoch).TotalMilliseconds:(long)(date-epoch).TotalSeconds)+(long)(Read(b,at,width)%scale);
        if(stamp<0)throw new ArgumentException("QR date out of range.");Write(b,at,width,(ulong)stamp);
    }
    static int Region(string s,bool mask) { switch(s.ToUpperInvariant()){case "JP":return 1;case "NA":return 2;case "EU":return mask?4:3;default:throw new ArgumentException("Unknown region: "+s);} }
    static byte[] Build2(string key) {
        string file;int length,control,marker;ulong identity,timestamp;int[] equipment;
        switch(key) {
            case "normal-shiroganemaru":file="050-shiroganemaru.json";length=120;identity=109968711517340;timestamp=404073806272;control=1;equipment=new int[5];marker=11;break;
            case "normal-koganemaru":file="070-koganemaru.json";length=120;identity=109968711517340;timestamp=406838805493;control=1;equipment=new int[5];marker=11;break;
            case "special-shotaro":file="010-shotaro.json";length=288;identity=256450756757790;timestamp=347155566496;control=792;equipment=new int[]{0,0,0,460,0};marker=515;break;
            case "special-chris":file="020-chris.json";length=288;identity=27603718631432;timestamp=407676047465;control=1;equipment=new int[]{0,0,0,0,673};marker=803;break;
            case "special-iwata":file="030-iwata.json";length=288;identity=181998431241473;timestamp=410350269286;control=10;equipment=new int[]{408,512,0,0,0};marker=515;break;
            case "special-yamana":file="040-yamana.json";length=288;identity=159425908194132;timestamp=410350438158;control=12;equipment=new int[]{409,512,0,0,631};marker=515;break;
            default:throw new ArgumentException("Unknown RPG2 definition: "+key);
        }
        Dictionary<string,object> t=Template(2,file),fields=(Dictionary<string,object>)t["Fields"];
        byte[] b=new byte[length];Ascii(b,0,length==120?"1_2D":"PS2D");Write(b,4,2,1);b[6]=1;b[7]=2;
        Write(b,8,6,identity);Write(b,0x30,6,timestamp);Write(b,0x38,2,(ulong)control);
        for(int i=0;i<5;i++)Bits(b,0x38,16+i*10,10,equipment[i]);if(length==288)b[0x40]|=4;
        Name(b,2,Str(t,"Name"));Write(b,0x5e,2,(ulong)marker);
        foreach(KeyValuePair<string,int> f in map2)if(fields.ContainsKey(f.Key))b[f.Value]=(byte)Number(Str(fields,f.Key),2,false);
        b[0x65]=(byte)((Number(Str(fields,"--face-image"),2,false)<<4)|Number(Str(fields,"--face-shape"),2,false));
        if(length==288){Write(b,0x6e,2,Convert.ToUInt64(t["Claim"]));b[0x70]=1;}
        else {
            // Normal-only zero defaults: combined probe E accepted on hardware.
            // Keep known level/date/antenna data. Zero identity passed normal-QR hardware tests.
            b[7]=0;b[0x5e]&=7;Array.Clear(b,8,6);
        }
        Finish(b);return b;
    }
    static byte[] Normal3(string key) {
        string name;uint timestamp;int mask,control;int[] flags,fields;
        switch(key) {
            case "jp":name="あいな";timestamp=745842466;mask=1;control=0x0101;flags=new int[]{1,3,0x67,0xc7};fields=new int[]{0x19,0x13,1,0x11,3,8,1,3,0,0,0x1b,0x18,2,9,4,8};break;
            case "eu":name="Hann";timestamp=778276500;mask=4;control=0x01b9;flags=new int[]{0,3,7,0xc7};fields=new int[]{0x13,0x17,4,3,1,0x1b,0,0x0b,1,0,4,1,1,0,3,6};break;
            case "na":name="Aiyana";timestamp=777932310;mask=2;control=0x0302;flags=new int[]{2,2,2,0x2d};fields=new int[]{0xde,0x0b,0x0a,0,0x11,0x1c,0x14,0x12,0,0,7,3,3,1,4,0x44};break;
            default:throw new ArgumentException("Unknown RPG3 normal definition: "+key);
        }
        byte[] b=new byte[88];Ascii(b,0,"1_3D");Write(b,4,4,timestamp);Name(b,3,name);
        if(key=="na"){Write(b,0x16,2,2);Text(b,0x18,"Alai");}
        int[] at={0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2a,0x2c,0x2d,0x2e,0x31,0x32};for(int i=0;i<at.Length;i++)b[at[i]]=(byte)fields[i];
        at=new int[]{0x30,0x33,0x35,0x36};for(int i=0;i<at.Length;i++)b[at[i]]=(byte)flags[i];Write(b,0x50,2,(ulong)mask);Write(b,0x52,2,(ulong)control);
        // Normal-only zero defaults: combined probe D accepted on hardware.
        // Preserve source-date mode at 0x53 and region mask at 0x50.
        // User-selected normal-QR defaults. EU E8 is one observed sample, not a confirmed language enum.
        b[0x30]=0;b[0x52]=(byte)(key=="jp"?1:key=="na"?2:0);Finish(b);return b;
    }
    static byte[] Special3(string key) {
        string file;int[] controls;
        switch(key){
            case "hunt":file="040-hunt.json";controls=new int[]{0,0,1,2,1};break;
            case "jiya":file="050-jiya.json";controls=new int[]{0x10,0,1,0x0a,0x14};break;
            case "jack":file="060-jack.json";controls=new int[]{0,0x10,0,1,1};break;
            case "kiki":file="070-kiki.json";controls=new int[]{0,0x12,0,1,1};break;
            case "rudolph":file="080-rudolph.json";controls=new int[]{0x20,0,1,9,1};break;
            case "santa":file="090-santa.json";controls=new int[]{0,0,0,1,1};break;
            default:throw new ArgumentException("Unknown special definition: "+key);
        }
        Dictionary<string,object> t=Template(3,file);byte[] b=new byte[160];Ascii(b,0,"2S3D");Date(b,3,Str(t,"Date"));Name(b,3,Str(t,"Name"));
        foreach(KeyValuePair<string,object> f in (Dictionary<string,object>)t["Fields"]){if(!map3.ContainsKey(f.Key))throw new ArgumentException("Unknown template field.");b[map3[f.Key]]=(byte)Number(Convert.ToString(f.Value),2,false);}
        b[0x34]=(byte)Number(Str(t,"Monster"),2,false);b[0x54]=(byte)Number(Str(t,"Special"),2,false);b[0x55]=(byte)Decimal(Str(t,"Quantity"),3,255);
        System.Collections.IList items=(System.Collections.IList)t["Items"];if(items.Count!=4)throw new ArgumentException("Expected four items.");for(int i=0;i<4;i++)Write(b,0x56+i*2,2,(ulong)Number(Convert.ToString(items[i]),4,false));
        int[] at={0x2b,0x30,0x33,0x35,0x36};for(int i=0;i<at.Length;i++)b[at[i]]=(byte)controls[i];Write(b,0x50,2,1);Write(b,0x52,2,0x0103);
        // Experimental verification defaults requested for special QRs.
        // Preserve known level, evolution, correction, rewards and date mode.
        b[0x2b]=0;b[0x30]=0;b[0x52]=3;Finish(b);return b;
    }
    public static byte[] Plain(int game,string carrier) {
        if(game==2 && carrier.StartsWith("generated2:",StringComparison.Ordinal))return Build2(carrier.Substring(11));
        if(game==3 && carrier.StartsWith("generated:",StringComparison.Ordinal))return Special3(carrier.Substring(10));
        if(game==3 && carrier.StartsWith("generated3:normal-",StringComparison.Ordinal))return Normal3(carrier.Substring(18));
        return Cipher().Transform(game==2?Bytes(carrier,120,288):Bytes(carrier,88,160),true);
    }
    static Dictionary<string,int[][]> antennaEvolution3;
    public static int[] AntennaStage3(int antenna,int level) {
        return AntennaStage3(antenna,level,0);
    }
    public static int[] AntennaStage3(int antenna,int level,int correction) {
        if(level<1||level>199)throw new ArgumentException("Source level must be 1-199.");
        if(correction<0||correction>15)throw new ArgumentException("Correction must be 0-F.");
        if(antennaEvolution3==null)antennaEvolution3=json.Deserialize<Dictionary<string,int[][]>>(File.ReadAllText(Path.Combine(root,"data/rpg3-antenna-evolution.json"),Encoding.UTF8));
        int[][] stages;
        if(!antennaEvolution3.TryGetValue(antenna.ToString("X2",CultureInfo.InvariantCulture),out stages))throw new ArgumentException("Unsupported antenna evolution.");
        int appearance=antenna==0?0:1,stage=0;
        foreach(int[] row in stages){if(row.Length!=3)throw new ArgumentException("Invalid antenna evolution data.");int requiredLevel=row[0];if(correction==8&&row[2]>=2)requiredLevel-=3;if(level>=requiredLevel){appearance=row[1];stage=row[2];}}
        return new int[]{appearance,stage};
    }
    static void Special(byte[] b,int game) { if(b.Length!=(game==2?288:160))throw new ArgumentException("This option requires a special QR."); }
    public static byte[] Edit(int game,Dictionary<string,string> v) {
        if(game!=2&&game!=3)throw new ArgumentException("Unknown game.");
        if(v.ContainsKey("--code"))throw new ArgumentException("Game code files are not accepted.");
        byte[] b=Plain(game,v["--carrier"]);Validate(b);
        if(game==2){string magic=Encoding.ASCII.GetString(b,0,4);if(magic!="1_2D"&&magic!="PS2D")throw new ArgumentException("Not an RPG2 QR.");}
        if(game==3 && v.ContainsKey("--character-carrier")){
            Special(b,3);byte[] c=Plain(3,v["--character-carrier"]);if(c.Length!=88)throw new ArgumentException("Expected normal character QR.");Validate(c);Array.Copy(c,8,b,8,0x48);Name(b,3,Name(c,3));
        }
        if(game==2 && v.ContainsKey("--region")){Write(b,4,2,(ulong)Region(v["--region"],true));b[6]=(byte)Region(v["--region"],false);}
        if(v.ContainsKey("--name"))Name(b,game,v["--name"]);if(v.ContainsKey("--qr-date"))Date(b,game,v["--qr-date"]);
        if(game==3 && (v.ContainsKey("--correction")||v.ContainsKey("--evasion-bonus"))){
            int n;if(v.ContainsKey("--correction"))n=Number(v["--correction"],2,true);else{string s=v["--evasion-bonus"];if(s!="0"&&s!="1")throw new ArgumentException("Evasion flag must be 0 or 1.");n=s=="1"?6:0;}
            if(n>15)throw new ArgumentException("Correction must be 0-F.");b[0x35]=(byte)((b[0x35]&15)|(n<<4));
        }
        foreach(KeyValuePair<string,int> f in game==2?map2:map3)if(v.ContainsKey(f.Key)){if(game==3&&f.Key.StartsWith("--special-",StringComparison.Ordinal))Special(b,3);b[f.Value]=(byte)Number(v[f.Key],2,true);}
        if(v.ContainsKey("--paint-color")){
                int color=Number(v["--paint-color"],2,true);
                if(color!=255&&color>32)throw new ArgumentException("Paint color must be 00-20, or FF for no paint.");
                b[game==2?0x0f:0x2f]=(byte)(color==255?0:game==2?color+1:(color<<1)|1);
        }
        if(game==3){
            if(v.ContainsKey("--source-level")){
                int level=Decimal(v["--source-level"],3,199);int[] evolution=AntennaStage3(b[0x32],level,b[0x35]>>4);
                b[0x20]=(byte)evolution[0];b[0x33]=(byte)evolution[1];Write(b,0x36,2,(ulong)level);
            }
            foreach(KeyValuePair<string,int> f in stats)if(v.ContainsKey(f.Key))Write(b,f.Value,2,(ulong)Decimal(v[f.Key],4,f.Key=="--evade-bonus"?50:9999));
            if(v.ContainsKey("--special-quantity")){Special(b,3);b[0x55]=(byte)Decimal(v["--special-quantity"],3,255);b[0x56]=0;}
            string[] items={"--special-item","--special-item-2","--special-item-3","--special-item-4"};for(int i=0;i<4;i++)if(v.ContainsKey(items[i])){Special(b,3);Write(b,0x56+i*2,2,(ulong)Number(v[items[i]],4,false));}
            if(v.ContainsKey("--special-region-mask")){Special(b,3);int n=Number(v["--special-region-mask"],4,false);if(n==0)throw new ArgumentException("Region mask must not be zero.");Write(b,0x50,2,(ulong)n);}
        }else{
            string[] faces={"--face-image","--face-shape"};foreach(string f in faces)if(v.ContainsKey(f)){int n=Number(v[f],2,true);if(n>15)throw new ArgumentException("Face value must be 0-F.");b[0x65]=(byte)(f==faces[0]?((b[0x65]&15)|(n<<4)):((b[0x65]&240)|n));}
            string[] claims={"--official-claim-id","--equipment-item"};foreach(string f in claims)if(v.ContainsKey(f)){Special(b,2);Write(b,0x6e,2,(ulong)Number(v[f],4,true));}
            if(v.ContainsKey("--official-item-candidate")){Special(b,2);Write(b,0x3a,2,(ulong)Number(v["--official-item-candidate"],4,true));}
            string[] eq={"--official-neck-equipment","--official-arm-equipment","--official-back-equipment","--official-feet-equipment","--official-clothing"};int[] bit={16,26,46,36,56};for(int i=0;i<eq.Length;i++)if(v.ContainsKey(eq[i])){Special(b,2);int n=Number(v[eq[i]],4,true);if(i==4&&n>=0x400)n-=0x400;Bits(b,0x38,bit[i],10,n);}
            if(v.ContainsKey("--official-equipment")){Special(b,2);Write(b,0x3a,2,(ulong)Number(v["--official-equipment"],4,true));}
            if(v.ContainsKey("--official-equipment-block")){Special(b,2);Bytes(Regex.Replace(v["--official-equipment-block"],@"\A0x","",RegexOptions.IgnoreCase),10).CopyTo(b,0x38);}
            string[] words={"--official-equipment-38","--official-equipment-40","--equipment-control"};int[] at={0x38,0x40,0x70};for(int i=0;i<3;i++)if(v.ContainsKey(words[i])){Special(b,2);Write(b,at[i],2,(ulong)Number(v[words[i]],4,true));}
            if(v.ContainsKey("--official-equipment-3f")){Special(b,2);b[0x3f]=(byte)Number(v["--official-equipment-3f"],2,true);}
            foreach(string f in new string[]{"--official-special-region","--official-experiment-region"})if(v.ContainsKey(f)){Special(b,2);b[0x6f]=1;Array.Clear(b,0x70,4);b[0x70]=(byte)Region(v[f],false);}
        }
        if(game==2&&v.ContainsKey("--rpg3-ability"))CallLabAdjust2(b,Number(v["--rpg3-ability"],2,true));
        // Explicit advanced overrides only; never accept arbitrary offsets.
        if(game==2){
            string[] slots={"neck","arm","back","feet","clothing"};int[] shifts={0,10,30,20,40};bool changed=false;
            for(int i=0;i<slots.Length;i++){string option="--qr-equipment-"+slots[i];if(v.ContainsKey(option)){int value=Number(v[option],4,true);if(i==4&&value>=0x400)value-=0x400;Bits(b,0x3a,shifts[i],10,value);changed=true;}}
            if(changed){ulong packed=Read(b,0x3a,8);bool equipped=false;for(int i=0;i<5;i++)if(((packed>>(10*i))&1023UL)!=0)equipped=true;b[0x40]=(byte)((b[0x40]&~4)|(equipped?4:0));}
        }
        if(game==2&&v.ContainsKey("--source-level")){int level=Decimal(v["--source-level"],2,99);if(level<1)throw new ArgumentException("Source level must be 1-99.");Write(b,0x38,1,(ulong)level);}
        if(game==2){
            for(int at=8;at<=13;at++){
                string option="--qr-identity-"+at.ToString("X2",CultureInfo.InvariantCulture);
                if(v.ContainsKey(option))b[at]=(byte)Number(v[option],2,false);
            }
        }
        if(game==3&&v.ContainsKey("--qr-date-mode")){
            int mode=Number(v["--qr-date-mode"],2,false);if(mode<1||mode>3)throw new ArgumentException("Date mode must be 01-03.");int originAt=b.Length==160?0x52:0x53;b[originAt]=(byte)((b[originAt]&248)|mode);
        }
        string[] advanced=game==3?new string[]{"--qr-meta-2b","--qr-meta-30","--qr-flags-52","--qr-origin-53"}:new string[]{"--qr-meta-07","--qr-meta-39","--qr-marker-70","--qr-marker-71","--qr-marker-72","--qr-marker-73"};
        int[] offsets=game==3?new int[]{0x2b,0x30,0x52,0x53}:new int[]{7,0x39,0x70,0x71,0x72,0x73};
        for(int i=0;i<advanced.Length;i++)if(v.ContainsKey(advanced[i])){
            int value=Number(v[advanced[i]],2,false);if(advanced[i]=="--qr-origin-53"&&value>7)throw new ArgumentException("Origin must be 00-07.");b[offsets[i]]=(byte)value;
        }
        if(game==2&&v.ContainsKey("--qr-meta-5e-upper")){int upper=Number(v["--qr-meta-5e-upper"],2,false);if(upper>31)throw new ArgumentException("Upper metadata must be 00-1F.");b[0x5e]=(byte)((b[0x5e]&7)|(upper<<3));}
        if(game==3){
            string[] extra={"--qr-special-meta-5e","--qr-special-meta-5f"};
            for(int i=0;i<extra.Length;i++)if(v.ContainsKey(extra[i])){Special(b,3);b[0x5e+i]=(byte)Number(v[extra[i]],2,false);}
        }
        if(v.ContainsKey("--memo")){
            if(game!=2 && !(game==3 && b.Length==160))throw new ArgumentException("RPG3 memo requires a special QR; normal RPG3 has no memo field.");
            string memo=v["--memo"];
            if(memo.Length>16||memo.IndexOf('\0')>=0)throw new ArgumentException("Memo must be at most 16 UTF-16 code units, without NUL.");
            byte[] text=new UnicodeEncoding(false,false,true).GetBytes(memo);
            int memoAt=game==2?0x10:0x78;
            Array.Clear(b,memoAt,32);text.CopyTo(b,memoAt);
            if(game==3){
                int region=0;int mask=b[0x50]|(b[0x51]<<8);
                while(region<6 && (mask&(1<<region))==0)region++;
                if(!v.ContainsKey("--qr-special-meta-5f"))b[0x5f]=(byte)region;
                if(!v.ContainsKey("--qr-special-meta-5e"))b[0x5e]=(byte)(region==0?1:region==1?2:3);
            }
        }
        if(game==3){
            string[] equipment={"--neck-equipment","--arm-equipment","--feet-equipment","--back-equipment","--clothing-equipment"};
            for(int i=0;i<equipment.Length;i++)if(v.ContainsKey(equipment[i]))Write(b,0x44+i*2,2,(ulong)Number(v[equipment[i]],4,false));
        }
        // Explicit research inputs run last, so masked fields preserve equipment/other nibbles.
        if(game==2){
            foreach(int at in new int[]{0x0e,0x42,0x43,0x44,0x45,0x5f}){
                string option="--qr2-raw-"+at.ToString("X2",CultureInfo.InvariantCulture);
                if(v.ContainsKey(option))b[at]=(byte)Number(v[option],2,false);
            }
            if(v.ContainsKey("--qr2-equipment-reserved"))Bits(b,0x3a,51,13,Number(v["--qr2-equipment-reserved"],4,false));
            if(v.ContainsKey("--qr2-mode-low"))Bits(b,0x5e,0,3,Number(v["--qr2-mode-low"],2,false));
            for(int at=0x6e;at<=0x73;at++){
                string option="--qr2-tail-"+at.ToString("X2",CultureInfo.InvariantCulture);
                if(v.ContainsKey(option)){if(b.Length!=120)throw new ArgumentException("Normal RPG2 tail override requires normal QR.");b[at]=(byte)Number(v[option],2,false);}
            }
        }else{
            if(v.ContainsKey("--qr3-growth-low"))Bits(b,0x35,0,4,Number(v["--qr3-growth-low"],2,false));
            if(v.ContainsKey("--qr3-origin-low"))Bits(b,b.Length==160?0x52:0x53,0,3,Number(v["--qr3-origin-low"],2,false));
            foreach(int at in new int[]{0x4e,0x4f}){
                string option="--qr3-raw-"+at.ToString("X2",CultureInfo.InvariantCulture);
                if(v.ContainsKey(option))b[at]=(byte)Number(v[option],2,false);
            }
            for(int at=0x98;at<=0x9b;at++){
                string option="--qr3-padding-"+at.ToString("X2",CultureInfo.InvariantCulture);
                if(v.ContainsKey(option)){Special(b,3);if(b[0x53]!=1)throw new ArgumentException("Padding override requires a single-entry special QR.");b[at]=(byte)Number(v[option],2,false);}
            }
        }
        Finish(b);return Cipher().Transform(b,false);
    }
    public static byte[] Baseline1() {
        byte[] b=new byte[53];Ascii(b,0,"bX80");
        int[][] fields={new int[]{8,0,6,4},new int[]{19,6,7,70},new int[]{8,6,5,8},new int[]{17,0,4,9},new int[]{9,3,5,3},new int[]{18,0,7,95},new int[]{10,5,6,16},new int[]{20,5,7,99},new int[]{11,3,5,1},new int[]{12,0,5,2},new int[]{12,5,5,1},new int[]{13,3,4,4},new int[]{14,0,6,11},new int[]{15,3,5,3},new int[]{22,0,7,99},new int[]{16,5,3,3},new int[]{20,0,5,17}};
        foreach(int[] f in fields)Bits(b,f[0],f[1],f[2],f[3]);Text(b,26,"じゅり");Write(b,38,5,930618007228);Write(b,50,3,3136335);return b;
    }
    public static byte[] Encrypt1(byte[] b) {
        if(b==null||b.Length!=53)throw new ArgumentException("RPG1 requires 53 bytes.");
        byte[] output=new byte[106];
        for(int i=0;i<b.Length;i++) {
            // Hardware-tested comparison C: n=0, so a=p. No copied parameter
            // table or variable transform is needed to encode this profile.
            output[2*i]=b[i];
            output[2*i+1]=0;
        }
        return output;
    }
    public static byte[] Decrypt1(byte[] b) {
        if(b.Length!=106)throw new ArgumentException("RPG1 requires 106 bytes.");byte[] output=new byte[53];for(int i=0;i<53;i++){int n=b[2*i+1];output[i]=(byte)(n^(((b[2*i]^n)-n*n)&255));}return output;
    }
    public static string Run(int game,string[] args) {
        int start=args.Length>0 && args[0].EndsWith(".mjs",StringComparison.OrdinalIgnoreCase)?1:0;
        if(args.Length<=start)throw new ArgumentException("Command required.");string command=args[start];
        if(game==0){if(command!="render"||args.Length!=start+3)throw new ArgumentException("Expected render command.");Render(Bytes(args[start+1],88,106,120,160,288),args[start+2]);return "作成: "+args[start+2];}
        if(game==1){
            if(command=="baseline") { byte[] p=Baseline1();return json.Serialize(new Dictionary<string,string>{{"plainHex",Hex(p)},{"cipherHex",Hex(Encrypt1(p))}}); }
            if(command=="encrypt-generated"&&args.Length==start+2)return Hex(Encrypt1(Bytes(args[start+1],53)));
            if(command=="decrypt"&&args.Length==start+2)return Hex(Decrypt1(Bytes(args[start+1],106)));
            throw new ArgumentException("Unknown RPG1 command.");
        }
        if(command!="edit")throw new ArgumentException("Expected edit command.");
        Dictionary<string,string> values=new Dictionary<string,string>();for(int i=start+1;i<args.Length;i+=2){if(i+1>=args.Length||!args[i].StartsWith("--",StringComparison.Ordinal))throw new ArgumentException("Invalid arguments.");values[args[i]]=args[i+1];}
        byte[] payload=Edit(game,values);
        if(values.ContainsKey("--hex-out"))using(FileStream f=new FileStream(values["--hex-out"],FileMode.CreateNew))using(StreamWriter w=new StreamWriter(f,new UTF8Encoding(false)))w.Write(Hex(payload)+"\n");
        if(values.ContainsKey("--png")){Render(payload,values["--png"]);return "作成: "+values["--png"]+Environment.NewLine+"内容: "+Hex(payload);}
        return values.ContainsKey("--hex-out")?"":Hex(payload);
    }
}

sealed class Blowfish {
    readonly uint[] p=new uint[18];readonly uint[][] s={new uint[256],new uint[256],new uint[256],new uint[256]};
    public Blowfish(byte[] initial) {
        if(initial.Length!=1042*4||BitConverter.ToUInt32(initial,0)!=0x243f6a88)throw new ArgumentException("Invalid standard Blowfish constants.");
        for(int i=0;i<18;i++)p[i]=BitConverter.ToUInt32(initial,i*4);for(int box=0;box<4;box++)for(int i=0;i<256;i++)s[box][i]=BitConverter.ToUInt32(initial,(18+box*256+i)*4);
        byte[] key=Core.Bytes("d0959870cfe0feaebbaef0d670fbbdf0");int k=0;unchecked{for(int i=0;i<18;i++){uint word=0;for(int j=0;j<4;j++){word=(word<<8)|key[k];k=(k+1)%key.Length;}p[i]^=word;}}
        uint left=0,right=0;for(int i=0;i<18;i+=2){Words(ref left,ref right,false);p[i]=left;p[i+1]=right;}for(int box=0;box<4;box++)for(int i=0;i<256;i+=2){Words(ref left,ref right,false);s[box][i]=left;s[box][i+1]=right;}
    }
    uint F(uint x) { unchecked{return ((s[0][x>>24]+s[1][(x>>16)&255])^s[2][(x>>8)&255])+s[3][x&255];} }
    void Words(ref uint left,ref uint right,bool decrypt) {
        for(int i=decrypt?17:0;decrypt?i>1:i<16;i+=decrypt?-1:1){left^=p[i];right^=F(left);uint t=left;left=right;right=t;}
        uint temp=left;left=right;right=temp;right^=p[decrypt?1:16];left^=p[decrypt?0:17];
    }
    public byte[] Transform(byte[] b,bool decrypt) {
        if(b.Length%8!=0)throw new ArgumentException("Blowfish input must contain full blocks.");byte[] output=new byte[b.Length];
        for(int at=0;at<b.Length;at+=8){uint left=BitConverter.ToUInt32(b,at),right=BitConverter.ToUInt32(b,at+4);Words(ref left,ref right,decrypt);BitConverter.GetBytes(left).CopyTo(output,at);BitConverter.GetBytes(right).CopyTo(output,at+4);}return output;
    }
}
}
