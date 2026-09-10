using Gala;
using System.Drawing;
static void Check(bool ok,string name){if(!ok)throw new Exception(name);Console.WriteLine("PASS: "+name);}
var g=new Game(100,7);var r=g.Spawn(Kind.Adult,100)!;
g.Select(Tool.Vacuum);Check(g.State.Tool==Tool.Pinch,"locked tools");
g.Use(r.Id,101,0);Check(r.FlyingUntil==103.8&&g.State.Captures==0,"flight escape");
g.Use(r.Id,102,1);Check(r.Live,"cannot hit airborne roach");
g.Use(r.Id,104,1);Check(r.Kind==Kind.Stain&&g.State.Xp==2,"pinch leaves persistent stain");
g.State.Xp=28;g.Select(Tool.Vacuum);g.Use(r.Id,105);Check(g.State.Residents.Contains(r),"vacuum cannot erase stain");
g.Select(Tool.Cleaner);g.Use(r.Id,106);Check(g.State.Residents.Count==0,"cleaner removes stain");
foreach(var k in new[]{Kind.Egg,Kind.Corpse,Kind.Adult,Kind.Baby}){r=g.Spawn(k,110)!;r.FlyingUntil=200;g.Select(Tool.Vacuum);g.Use(r.Id,111);Check(!g.State.Residents.Contains(r),"vacuum "+k);}
g.Select(Tool.Poison);g.Folder(120);Check(g.State.Residents.Count(r=>r.Kind==Kind.Corpse)==3&&g.State.Residents.Count(r=>r.Kind==Kind.Egg)==1,"poison folder burst spares eggs");
g.Tick(176,0);Check(g.State.Residents.Count(r=>r.Kind==Kind.Baby)==2,"eggs hatch into babies");
var copy=new Game(180);copy.Restore(g.Serialize());Check(copy.State.Xp==g.State.Xp&&copy.State.Poisoned&&copy.State.Residents.Count==g.State.Residents.Count&&copy.State.Residents.Where(r=>r.Live).All(r=>r.Hidden),"persistent progress and hidden reload");
var visit=new Game(100,2);visit.Screens=[new(-1440,0,1440,900)];r=visit.Spawn(Kind.Adult,100)!;Check(!r.Hidden,"edge appearance");double now=100;for(int i=0;i<3000&&!r.Hidden;i++){now+=1.0/30;visit.Tick(now,1.0/30);}Check(r.Hidden,"walk then completely leave screen");visit.Tick(now+10,0);Check(r.Hidden,"empty screen interval");
visit.State.Quiet=true;visit.Tick(now+100,0);Check(r.Hidden,"focus prevents reappearance");visit.TogglePause(now+101);var before=r.X;visit.Tick(now+200,1);Check(r.X==before&&visit.Paused,"pause freezes simulation");visit.TogglePause(now+201);Check(!visit.Paused&&r.Hidden,"resume preserves hiding");
var survivor=new Game(100);survivor.Tick(101,0);survivor.Tick(126,0);Check(survivor.State.Residents.Count==1&&survivor.State.Residents[0].Kind==Kind.Baby,"survivor returns");
for(int i=0;i<100;i++)survivor.Spawn(Kind.Adult,127);Check(survivor.State.Residents.Count==38,"population cap");
Console.WriteLine("All Windows gameplay model tests passed on this host.");
