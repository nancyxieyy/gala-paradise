namespace Gala;
public partial class Game {
 public string? ClipboardText;
 public void Summon(Resident r,double now){if(Paused||State.Life.FocusRemaining>0)return;var f=Screens[0];r.Screen=f;r.X=r.Kind==Kind.CatPaw?f.Right-220:f.Left+f.Width/2-80;r.Y=f.Top+170;if(r.Kind==Kind.CatPaw)r.Born=now-2;r.TargetX=r.X+80;r.TargetY=r.Y;r.ExitAt=now+8;r.Exiting=false;r.Hidden=false;State.Life.Observe(r,now);}
 public void LifeAction(string action,Guid? id,string text,string? note,double minutes=25,bool inPlace=false){
  var l=State.Life;double now=DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()/1000.0;ClipboardText=null;
  if((Paused||l.FocusRemaining>0)&&!new[]{"stash","return","done","delete","share","cancel"}.Contains(action)){Message="先结束专注或继续桌宠，再进行动物互动";return;}
  switch(action){
   case "stash":int count=l.Notes.Count;Message=l.Stash(text,now);var carrier=State.Residents.Find(r=>r.Id==id);if(l.Notes.Count>count&&carrier!=null&&!Paused&&l.FocusRemaining<=0){Summon(carrier,now);carrier.CarryUntil=now+4;}return;
   case "return":case "done":case "delete":
    var n=l.Notes.Find(n=>n.Id==note);if(n==null){Message="先选一条纸条";return;}if(action=="return"){ClipboardText=n.Text;l.Award("stash.return",now);Message="已复制纸条，原内容仍保留";}if(action=="done"){n.Done=!n.Done;Message="待办状态已更新";}if(action=="delete"){l.Notes.Remove(n);Message="已删除选中的纸条";}return;
   case "focus":l.FocusRemaining=Math.Clamp(double.IsFinite(minutes)?minutes:25,1,120)*60;foreach(var x in State.Residents.Where(r=>r.Live))x.Hidden=true;Message="专注开始，大家回窝了；关闭程序不会自动完成计时";return;
   case "cancel":l.FocusRemaining=0;NextAppearance=now+20;nextGold=now+30;nextMouse=now+60;nextCat=now+90;Message="计时已结束，不扣好感";return;
   case "safe":l.SafeLeft=!l.SafeLeft;Message="左半屏安全窝已"+(l.SafeLeft?"开启":"关闭");return;
   case "explore":if(!l.TraceReady){Message="还没有新脚印，稍后再来看看";return;}if(State.Residents.Count>=38){Message="住客已满，脚印会保留";return;}l.TraceReady=false;l.Award("trace.first",now);l.Award("nest.first",now);var found=Spawn(Kind.Gold,now);if(found!=null)Summon(found,now);Message="顺着金色碎屑找到一处小窝，试着与住客交朋友";return;
   case "coexist":if(l.Bonds.Values.Where(b=>b.Partner).Select(b=>b.Kind=="mouse"?"mouse":b.Kind=="catPaw"?"cat":"roach").Distinct().Count()<2){Message="先认识至少两种伙伴，再安排大家共居";return;}l.SafeLeft=true;var shown=new HashSet<string>();foreach(var guest in State.Residents.Where(r=>l.Bonds.TryGetValue(r.Id.ToString(),out var b)&&b.Partner)){string species=guest.Kind==Kind.Mouse?"mouse":guest.Kind==Kind.CatPaw?"cat":"roach";if(shown.Add(species)){Summon(guest,now);guest.X=species=="roach"?Screens[0].Left+60:Screens[0].Right-Rules.Canvas(guest.Kind)-20;guest.Y=Screens[0].Top+(species=="mouse"?310:170);guest.TargetX=guest.X;guest.TargetY=guest.Y;}}l.Award("coexist.first",now);Message="左侧留窝、右侧巡逻，伙伴错时来访；共居安排完成";return;
   case "adopt":if(State.Residents.Count>=38){Message="住客已满，先保留领养码";return;}var (adopted,msg)=l.Adopt(text.Trim(),now);Message=msg;if(adopted!=null){State.Residents.Add(adopted);Summon(adopted,now);}return;
  }
  var r=State.Residents.Find(r=>r.Id==id&&r.Live);if(r==null){Message="先选择一位住客；可撒面包屑邀请旮杂";return;}
  switch(action){
   case "share":ClipboardText=l.Share(r.Id,now);Message=ClipboardText==null?"先命名或培养成伙伴，再生成领养码":"领养码已复制。副本领养，不带纸条和资源";break;
   case "patrol":
    if(!r.Friend||!l.Bonds.TryGetValue(r.Id.ToString(),out var bond)||!bond.Partner){Message="请选择已成为伙伴的老鼠或猫";return;}if(now<l.GuardUntil){Message="伙伴还在值班，右半屏正在保持安静";return;}
    var targets=State.Residents.Where(x=>x.Live&&!x.Friend&&!l.Protects(x.Id)&&!x.Hidden&&x.X>=x.Screen.Left+x.Screen.Width/2).ToArray();foreach(var x in targets)x.Hidden=true;l.GuardSide="right";l.GuardUntil=now+60;Summon(r,now);if(targets.Length>0)l.Award(r.Kind==Kind.Mouse?"patrol.first":"guard.first",now);Message=$"右半屏值班 60 秒 · 驱赶 {targets.Length} 只；不伤害伙伴、不产生击杀奖励";break;
   case "gold":if(r.Kind!=Kind.Gold||!l.Bonds.TryGetValue(r.Id.ToString(),out var b)||b.Trust<2){Message="黄金旮杂信任达到 2 后，会留下一次卵壳";return;}int amount=l.Gold(r.Id,now);State.Progression.Shells+=amount;Message=amount>0?"它留给你 2 枚黄金卵壳，仍可以继续做朋友":"这位住客的卵壳已收获过啦";break;
   default:if(!inPlace)Summon(r,now);Message=action=="recall"?"它听见你了，出来见一面":l.Interact(r,action,text,now);break;
  }
 }
}
