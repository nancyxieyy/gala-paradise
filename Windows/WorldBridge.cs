using System.Security.Cryptography;
using System.Text;
namespace Gala;
public partial class Game {
 double worldAccumulator;ulong lastLoggedSequence;
 public bool Dirty=true;
 readonly Dictionary<string,System.Drawing.Rectangle> folderFrames=[];
 public void EnsureWorld(){if(State.World!=null)return;var w=new World((ulong)rng.Next(1,int.MaxValue));foreach(var pair in State.Habitat.Folders.OrderBy(x=>x.Key).Take(60)){int i=w.Habitat(pair.Key.ToLowerInvariant());w.habitats[i].activity=Math.Min(1,pair.Value.Visits/10);}foreach(var r in State.Residents.Where(r=>!r.Friend))w.Add(Life.KindName(r.Kind),"edge",r.Id.ToString(),false);State.World=w;State.Life.TraceReady=false;}
 public void ReconcileWorld(){EnsureWorld();var w=State.World!;var ids=State.Residents.Where(r=>!r.Friend).Select(r=>r.Id.ToString()).ToHashSet();foreach(var c in w.creatures.Where(c=>!ids.Contains(c.id)))w.Event(c.id,c.location,"removed by player",c.stage,"removed","player");w.creatures.RemoveAll(c=>!ids.Contains(c.id));foreach(var r in State.Residents.Where(r=>!r.Friend)){var c=w.creatures.Find(c=>c.id==r.Id.ToString());if(c==null){w.Add(Life.KindName(r.Kind),"edge",r.Id.ToString(),false);c=w.creatures.Find(c=>c.id==r.Id.ToString());}if(c!=null){if(c.stage!=Life.KindName(r.Kind)){if(c.roach&&!r.Live)w.deaths++;w.Event(c.id,c.location,"tool",c.stage,Life.KindName(r.Kind),"player");}c.stage=Life.KindName(r.Kind);c.protection=State.Life.Protects(r.Id)||(State.Life.SafeLeft&&r.X<Screens[0].Left+Screens[0].Width/2);c.trust=State.Life.Bonds.GetValueOrDefault(r.Id.ToString())?.Trust??0;}}}
 public void WorldSignal(string kind,Guid? id=null,string? location=null){ReconcileWorld();var w=State.World!;string key=id?.ToString()??"";string loc=location??w.creatures.Find(c=>c.id==key)?.location??"edge";Blind?.Action(kind,key,loc,w.time);w.Send(new(kind,loc,key));Dirty=true;}
 public static string LocationKey(string identity)=>Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(identity))).ToLowerInvariant();
 public void StepWorld(double now){
  var prior=State.Residents.ToDictionary(r=>r.Id);ReconcileWorld();var w=State.World!;w.capacity=Math.Max(0,38-State.Residents.Count(r=>r.Friend));w.Step(State.Habitat.Rate);if(Blind==null&&Environment.GetCommandLineArgs().Contains("--world-log"))foreach(var e in w.recentEvents.Where(e=>(e.sequence??0)>lastLoggedSequence)){Console.WriteLine(System.Text.Json.JsonSerializer.Serialize(e));lastLoggedSequence=e.sequence??lastLoggedSequence;}var ids=w.creatures.Select(c=>c.id).ToHashSet();State.Residents.RemoveAll(r=>!r.Friend&&!ids.Contains(r.Id.ToString()));
  foreach(var c in w.creatures){if(!Guid.TryParse(c.id,out var id)||!Enum.TryParse<Kind>(c.stage,true,out var kind))continue;var r=State.Residents.Find(r=>r.Id==id);if(r==null){r=new Resident{Id=id,Kind=kind,X=12,Y=24,Born=now,Screen=Screens[0]};State.Residents.Add(r);}else{if(r.Live&&kind==Kind.Corpse&&c.playerChemical){State.Life.Defeat(now);State.Captures++;State.Xp+=2;if(r.Kind==Kind.Gold)State.Progression.Shells+=State.Life.Gold(id,now);}if(r.Kind!=kind){r.Kind=kind;r.Born=now;}}
   r.EcologyIntent=c.intent;
  }
  ProjectReadable(prior,now);Blind?.Observe(w);
  foreach(var c in w.creatures){var r=State.Residents.Find(r=>r.Id.ToString()==c.id);if(r==null)continue;
   if(!r.Live){r.Hidden=false;continue;}if(MigrationViews.ContainsKey(r.Id))continue;
   if(c.visibleUntil>w.time&&r.Hidden&&VisibleCount<3&&now>=NextAppearance){BeginVisit(r,now,HabitatAnchor(c.location));}
   if(c.intent=="freeze"&&!r.Hidden)r.HoldUntil=now+2;
   if((c.intent is "hide" or "rest" or "nest")&&!r.Hidden&&r.HoldUntil<now)r.ExitAt=Math.Min(r.ExitAt,now+1);
  }
  State.Life.TraceReady=w.habitats.Any(h=>h.nest&&h.exposed&&!h.discovered);
  if(EnableEncounters&&w.visitorKind.Length>0&&Enum.TryParse<Kind>(w.visitorKind,true,out var k)&&State.Residents.Count(r=>r.Kind==k&&!r.Hidden)<(k==Kind.Mouse?2:1))SpawnFriend(k,now);
  Dirty=true;
 }
}
