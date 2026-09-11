using System.Drawing;
namespace Gala;
public class MigrationViewState {public string Destination="";public double? DepartedAt;}
public record CueSnapshot(PointF Position,double Chemical=0,double Crumbs=0,bool Shell=false);
public partial class Game {
 public Dictionary<string,PointF> HabitatAnchors=[];
 public Dictionary<string,CueSnapshot> ReadableCues=[];
 public Dictionary<Guid,MigrationViewState> MigrationViews=[];
 readonly Dictionary<string,double> shellExpiry=[];
 ulong lastProjectedSequence;
 public PointF HabitatAnchor(string location){
  if(HabitatAnchors.TryGetValue(location,out var p))return p;
  var f=Screens[0];int index=Math.Max(0,State.World!.habitats.FindIndex(h=>h.id==location));
  p=folderFrames.TryGetValue(location,out var frame)?new(frame.Left-32,frame.Bottom-110):new(index%2==0?f.Left+4:f.Right-120,f.Bottom-130-index/2%5*72);
  HabitatAnchors[location]=p;return p;
 }
 public void PrimeReadable(){lastProjectedSequence=State.World?.eventSerial??0;}
 public void ProjectReadable(Dictionary<Guid,Resident> prior,double now){
  var w=State.World!;var events=w.recentEvents.Where(e=>(e.sequence??0)>lastProjectedSequence).ToArray();lastProjectedSequence=w.eventSerial;
  foreach(var e in events.Where(e=>e.trigger=="incubation"))if(Guid.TryParse(e.entity,out var id)&&prior.TryGetValue(id,out var egg)){shellExpiry[e.entity]=w.time+12;ReadableCues["shell:"+e.entity]=new(new(egg.X,egg.Y+55),Shell:true);}
  foreach(var r in State.Residents){var c=w.creatures.Find(c=>c.id==r.Id.ToString());if(c==null)continue;r.EggProgress=c.stage=="egg"?Math.Min(1,c.age/180):0;
   if(!prior.ContainsKey(r.Id)){Resident? origin=Guid.TryParse(c.originEgg,out var parent)?prior.GetValueOrDefault(parent):null;var p=origin!=null?new PointF(origin.X,origin.Y):HabitatAnchor(c.location);r.X=p.X;r.Y=p.Y;r.Screen=Screens[0];
    if(c.stage=="egg")r.X+=w.creatures.Where(x=>x.stage=="egg"&&x.location==c.location).ToList().FindIndex(x=>x.id==c.id)*20;
    if(c.stage=="baby"&&origin!=null){r.Hidden=false;r.Exiting=false;r.ExitAt=now+6;r.TargetX=p.X+(w.creatures.IndexOf(c)%2==0?100:-100);r.TargetY=p.Y-30;}
   }
  }
  foreach(var e in events.Where(e=>e.trigger=="migration")){
   if(!Guid.TryParse(e.entity,out var id))continue;var r=State.Residents.Find(r=>r.Id==id&&r.Live);if(r==null)continue;
   if(MigrationViews.TryGetValue(id,out var pending)){pending.Destination=e.@new;continue;}
   if(r.Hidden&&VisibleCount<3)BeginVisit(r,now,HabitatAnchor(e.previous));
   var travel=new MigrationViewState{Destination=e.@new};MigrationViews[id]=travel;
   if(!r.Hidden){r.Exiting=true;var dest=HabitatAnchor(e.@new);r.TargetX=dest.X>=r.X?r.Screen.Right:r.Screen.Left-Rules.Canvas(r.Kind);r.TargetY=r.Y;}else travel.DepartedAt=w.time;
  }
  foreach(var (id,travel) in MigrationViews.ToArray()){
   var r=State.Residents.Find(r=>r.Id==id&&r.Live);if(r==null){MigrationViews.Remove(id);continue;}
   if(r.Hidden){if(travel.DepartedAt==null)travel.DepartedAt=w.time;else if(w.time-travel.DepartedAt>=4&&VisibleCount<3){var p=HabitatAnchor(travel.Destination);BeginVisit(r,now,p);r.TargetX=p.X+(p.X<Screens[0].Left+Screens[0].Width/2?130:-130);r.TargetY=p.Y-25;MigrationViews.Remove(id);}}
  }
  foreach(var(id,until)in shellExpiry.ToArray())if(w.time>=until){shellExpiry.Remove(id);ReadableCues.Remove("shell:"+id);}
  foreach(var key in ReadableCues.Keys.Where(x=>x.StartsWith("habitat:")).ToArray())ReadableCues.Remove(key);
  foreach(var h in w.habitats.OrderByDescending(h=>h.chemical+(h.nest?1:0)+h.activity).Take(8)){int population=w.creatures.Count(c=>c.roach&&c.location==h.id);double crumbs=h.nest?.9:Math.Min(.65,h.stable/120)*Math.Min(1,population/3.0)+h.activity*.15;if(h.chemical>0||crumbs>.12)ReadableCues["habitat:"+h.id]=new(HabitatAnchor(h.id),h.chemical,crumbs);}
 }
}
