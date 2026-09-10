using System.Text.Json;
using System.Text.Json.Serialization;
using System.Drawing;
namespace Gala;
public enum Tool { Pinch, Slipper, Poison, Vacuum, Cleaner }
public enum Kind { Adult, Baby, Egg, Corpse, Stain }
public static class Rules {
    public static readonly string[] Names=["捏一下","人字拖","蟑螂药","吸尘器","清洁剂"];
    public static readonly int[] Unlock=[0,5,12,20,28];
    public static readonly string[] Details=["噗叽！会留奶油污渍","啪！但它可能会飞","开文件夹时批量躺平","活的、死的、卵，都能吸","最后一步：把污渍擦掉"];
    public static float Size(Kind k)=>k==Kind.Baby?45:k==Kind.Egg?52:68;
}
public class Resident {
    public Guid Id {get;set;}=Guid.NewGuid();
    public Kind Kind {get;set;}
    public float X {get;set;}
    public float Y {get;set;}
    public double Born {get;set;}
    [JsonIgnore] public Rectangle? EntryFrame{get;set;}
    [JsonIgnore] public double EntryUntil{get;set;}
    [JsonIgnore] public bool Live=>Kind is Kind.Adult or Kind.Baby;
    [JsonIgnore] public bool Hidden {get;set;}=true;
    [JsonIgnore] public bool Exiting {get;set;}
    [JsonIgnore] public double ExitAt {get;set;}
    [JsonIgnore] public double FlyingUntil {get;set;}
    [JsonIgnore] public double TauntUntil {get;set;}
    [JsonIgnore] public float TargetX {get;set;}
    [JsonIgnore] public float TargetY {get;set;}
    [JsonIgnore] public Rectangle Screen {get;set;}
    [JsonIgnore] public float Direction {get;set;}=1;
}
public class SaveState {
    public Habitat Habitat{get;set;}=new();
    public int Version {get;set;}=1;
    public int Xp {get;set;}
    public int Captures {get;set;}
    public int Cleaned {get;set;}
    public int Fed {get;set;}
    public Tool Tool {get;set;}
    public bool Poisoned {get;set;}
    public bool Quiet {get;set;}
    public bool Explorer {get;set;}
    public List<Resident> Residents {get;set;}=[];
}
public class Game {
    public SaveState State=new();
    public Rectangle[] Screens=[new(0,0,1440,900)];
    public bool Paused;
    public string Message="住客们正在角落躲着。";
    public double NextAppearance;
    double lastEgg,emptySince,lastFeed=-10,lastFolder=-10,pauseStart;
    readonly Random rng;
    public int VisibleCount=>State.Residents.Count(r=>r.Live&&!r.Hidden);
    public Game(double now,int? seed=null){rng=seed.HasValue?new Random(seed.Value):new Random();NextAppearance=now+8;lastEgg=now;}
    double Range(double a,double b)=>a+rng.NextDouble()*(b-a);
    public void Select(Tool t){if(State.Xp<Rules.Unlock[(int)t]){Message=$"还差 {Rules.Unlock[(int)t]-State.Xp} 点，喂食或捕捉来解锁";return;}State.Tool=t;if(t==Tool.Poison)State.Poisoned=true;Message=$"已拿起{Rules.Names[(int)t]}，点击桌面上的目标";}
    public void Feed(double now){if(Paused)return;if(now-lastFeed<2){Message="嚼嚼嚼……稍等两秒再喂";return;}lastFeed=now;State.Xp+=3;State.Fed++;Spawn(Kind.Adult,now);if(State.Fed%2==0)Spawn(Kind.Egg,now);Message="面包屑 +3 生长点。旮杂：还有吗？";}
    public void Folder(double now,PointF? origin=null,string identity="preview",Rectangle? frame=null){if(Paused||State.Quiet||now-lastFolder<1.2)return;lastFolder=now;State.Xp++;var result=State.Habitat.Opened(identity,now);int firstSide=rng.Next(4);for(int i=0;i<result.Count;i++){int side=(firstSide+i)%4;var r=Spawn(State.Poisoned?Kind.Corpse:Kind.Adult,now,frame.HasValue?Habitat.Border(frame.Value,side,Range(.2,.8)):origin??new PointF(Screens[0].Left+160,Screens[0].Top+160));if(r!=null&&r.Live&&frame.HasValue){r.EntryFrame=frame;r.EntryUntil=now+2.5;r.TargetX=r.X+(side==0?-140:side==1?140:0);r.TargetY=r.Y+(side==2?-140:side==3?140:0);}}if(result.Eggs&&State.Residents.Count(r=>r.Kind==Kind.Egg)<7)Spawn(Kind.Egg,now);Message=State.Poisoned?"里面都躺平了……但卵还没事。":"开门！三只旮杂溜出来了";}
    public void Scan(double now){int count=State.Residents.RemoveAll(r=>r.Kind!=Kind.Stain);State.Habitat.Clean(now);Message=$"扫描清走 {count} 个住客／卵，防护 5 分钟；污渍手动擦";}
    public Resident? Spawn(Kind k,double now,PointF? origin=null){
        if(State.Residents.Count>=38)return null;var f=Screens[rng.Next(Screens.Length)];
        var r=new Resident{Kind=k,Born=now,X=f.Left+(float)Range(10,Math.Max(11,f.Width-110)),Y=f.Top+(float)Range(20,Math.Max(21,f.Height-160)),Screen=f};
        if(k==Kind.Egg){r.X=rng.Next(2)==0?f.Left+5:f.Right-95;r.Y=f.Bottom-(float)Range(140,210);}
        if(origin.HasValue){r.X=origin.Value.X;r.Y=origin.Value.Y;}
        r.Hidden=r.Live;State.Residents.Add(r);
        if(r.Live&&(origin.HasValue||VisibleCount==0))BeginVisit(r,now,origin);
        return r;
    }
    public void BeginVisit(Resident r,double now,PointF? origin=null){
        var f=origin.HasValue?Screens.FirstOrDefault(s=>s.Contains(Point.Round(origin.Value)),Screens[0]):Screens[rng.Next(Screens.Length)];r.Screen=f;
        int edge=rng.Next(4);r.X=edge==0?f.Left-110:edge==1?f.Right:f.Left+(float)Range(.2,.8)*f.Width;
        r.Y=edge==2?f.Top-110:edge==3?f.Bottom:f.Top+(float)Range(.2,.8)*f.Height;
        if(origin.HasValue){r.X=origin.Value.X;r.Y=origin.Value.Y;}
        r.TargetX=f.Left+(float)Range(.25,.75)*f.Width;r.TargetY=f.Top+(float)Range(.2,.7)*f.Height;
        r.Hidden=false;r.Exiting=false;r.ExitAt=now+Range(9,16);
    }
    public void Tick(double now,double dt){
        if(Paused)return;
        if(!State.Quiet)foreach(var r in State.Residents.Where(r=>r.Kind is Kind.Baby or Kind.Egg))r.Born-=dt*(State.Habitat.Rate-1);
        foreach(var r in State.Residents.Where(r=>r.Live)){
            if(r.Kind==Kind.Baby&&now-r.Born>120&&!State.Quiet)r.Kind=Kind.Adult;
            if(r.Hidden)continue;
            if(!r.Exiting&&now>=r.ExitAt){r.Exiting=true;var f=r.Screen;PointF[] exits=[new(f.Left-110,r.Y),new(f.Right,r.Y),new(r.X,f.Top-110),new(r.X,f.Bottom)];var p=exits.MinBy(p=>MathF.Abs(p.X-r.X)+MathF.Abs(p.Y-r.Y));r.TargetX=p.X;r.TargetY=p.Y;}
            float dx=r.TargetX-r.X,dy=r.TargetY-r.Y,d=MathF.Sqrt(dx*dx+dy*dy);r.Direction=dx>=0?1:-1;
            float step=(float)(dt*(r.FlyingUntil>now?190:58)*(State.Quiet ? 0.4 : 1));
            if(d<=Math.Max(1,step)){r.X=r.TargetX;r.Y=r.TargetY;if(r.Exiting){r.Hidden=true;NextAppearance=now+Range(22,45);}}
            else{r.X+=dx/d*step;r.Y+=dy/d*step;}
        }
        if(State.Quiet||now<State.Habitat.CleanUntil)return;
        if(VisibleCount==0&&now>=NextAppearance){var hidden=State.Residents.Where(r=>r.Live).ToArray();if(hidden.Length>0)BeginVisit(hidden[rng.Next(hidden.Length)],now);NextAppearance=now+Range(22,45);}
        var egg=State.Residents.FirstOrDefault(r=>r.Kind==Kind.Egg&&now-r.Born>55);
        if(egg!=null&&State.Residents.Count<38){State.Residents.Remove(egg);var baby=Spawn(Kind.Baby,now);if(baby!=null)baby.TauntUntil=now+5;Spawn(Kind.Baby,now);Message="角落的卵孵化了。没想到吧？";}
        if(State.Residents.Any(r=>r.Live)){emptySince=0;if(now-lastEgg>75/State.Habitat.Rate){lastEgg=now;if(State.Residents.Count(r=>r.Kind==Kind.Egg)<5)Spawn(Kind.Egg,now);}}
        else{if(emptySince==0)emptySince=now;if(now-emptySince>24){var baby=Spawn(Kind.Baby,now);if(baby!=null)baby.TauntUntil=now+5;emptySince=0;Message="漏网之鱼：你以为电脑干净了？";}}
    }
    public void TogglePause(double now){Paused=!Paused;if(Paused)pauseStart=now;else{var d=now-pauseStart;foreach(var r in State.Residents){r.Born+=d;r.ExitAt+=d;r.FlyingUntil+=d;r.TauntUntil+=d;}NextAppearance+=d;lastEgg+=d;if(emptySince>0)emptySince+=d;}Message=Paused?"全体暂停，可以安心办公":"住客们回来啦";}
    public void Use(Guid id,double now,double? flightRoll=null){
        var r=State.Residents.Find(r=>r.Id==id);if(r==null||Paused)return;var t=State.Tool;if(State.Xp<Rules.Unlock[(int)t])return;
        if(r.Live){
            if(t==Tool.Cleaner){Message="清洁剂只擦污渍，旮杂笑你了";return;}
            if(t==Tool.Poison){Message="药已放好，下次开文件夹见分晓";return;}
            if(r.FlyingUntil>now&&t!=Tool.Vacuum){Message="嘿嘿，打不到～等落地或用吸尘器";return;}
            if(r.Kind==Kind.Adult&&t!=Tool.Vacuum&&(flightRoll??rng.NextDouble())<.24){r.FlyingUntil=now+2.8;r.TauntUntil=now+2.8;Message="它居然起飞了！";return;}
            State.Captures++;State.Xp+=2;r.Hidden=false;
            if(t==Tool.Vacuum){State.Residents.Remove(r);Message="咻——吸走一只旮杂";}
            else{r.Kind=t==Tool.Pinch?Kind.Stain:Kind.Corpse;r.Born=now;Message=t==Tool.Pinch?"噗叽！得用清洁剂擦掉奶油污渍":"啪！已躺平，用吸尘器收尾";}
        }else if((r.Kind==Kind.Stain&&t==Tool.Cleaner)||((r.Kind is Kind.Egg or Kind.Corpse)&&t==Tool.Vacuum)){State.Residents.Remove(r);State.Xp+=2;State.Cleaned++;Message="清理完了……角落里呢？";}
        else Message=r.Kind==Kind.Stain?"这是顽固污渍，要用清洁剂":"用吸尘器收走吧";
    }
    public string Serialize()=>JsonSerializer.Serialize(State,new JsonSerializerOptions{WriteIndented=true});
    public void Restore(string json){State=JsonSerializer.Deserialize<SaveState>(json)??throw new InvalidDataException("空存档");State.Habitat.Rate=new[]{.25,1.0,3.0}.Contains(State.Habitat.Rate)?State.Habitat.Rate:1;State.Residents=State.Residents.Take(38).Where(r=>float.IsFinite(r.X)&&float.IsFinite(r.Y)).ToList();if(!Enum.IsDefined(State.Tool)||State.Xp<Rules.Unlock[(int)State.Tool])State.Tool=Tool.Pinch;foreach(var r in State.Residents)r.Hidden=r.Live;}
}
