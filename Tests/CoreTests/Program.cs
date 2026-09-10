using Gala;
using System.Drawing;
static void Check(bool ok,string name){if(!ok)throw new Exception(name);Console.WriteLine("PASS: "+name);}
var g=new Game(100,7){EnableEncounters=false};var r=g.Spawn(Kind.Adult,100)!;
g.Select(Tool.Vacuum);Check(g.State.Tool==Tool.Pinch,"locked tools");
g.Use(r.Id,101,0);Check(r.FlyingUntil==103.8&&g.State.Captures==0,"flight escape");
g.Use(r.Id,102,1);Check(r.Live,"cannot hit airborne roach");
g.Use(r.Id,104,1);Check(r.Kind==Kind.Stain&&g.State.Xp==2,"pinch leaves persistent stain");
g.State.Xp=28;g.State.Progression.Owned=Enum.GetValues<Tool>().ToList();g.Select(Tool.Vacuum);g.Use(r.Id,105);Check(g.State.Residents.Contains(r),"vacuum cannot erase stain");
g.Select(Tool.Cleaner);g.Use(r.Id,106);Check(g.State.Residents.Count==0,"cleaner removes stain");
foreach(var k in new[]{Kind.Egg,Kind.Corpse,Kind.Adult,Kind.Baby}){r=g.Spawn(k,110)!;r.FlyingUntil=200;g.Select(Tool.Vacuum);g.Use(r.Id,111);Check(!g.State.Residents.Contains(r),"vacuum "+k);}
g.Select(Tool.Poison);g.Folder(120);Check(g.State.Residents.Count(r=>r.Kind==Kind.Corpse)==2&&g.State.Residents.Count(r=>r.Kind==Kind.Egg)==1,"poison folder burst spares eggs");
g.Tick(176,0);Check(g.State.Residents.Count(r=>r.Kind==Kind.Baby)==2,"eggs hatch into babies");
var copy=new Game(180){EnableEncounters=false};copy.Restore(g.Serialize());Check(copy.State.Xp==g.State.Xp&&copy.State.Poisoned&&copy.State.Residents.Count==g.State.Residents.Count&&copy.State.Residents.Where(r=>r.Live).All(r=>r.Hidden),"persistent progress and hidden reload");
var visit=new Game(100,2){EnableEncounters=false};visit.Screens=[new(-1440,0,1440,900)];r=visit.Spawn(Kind.Adult,100)!;Check(!r.Hidden,"edge appearance");double now=100;for(int i=0;i<3000&&!r.Hidden;i++){now+=1.0/30;visit.Tick(now,1.0/30);}Check(r.Hidden,"walk then completely leave screen");visit.Tick(now+10,0);Check(r.Hidden,"empty screen interval");
visit.State.Quiet=true;visit.Tick(now+100,0);Check(r.Hidden,"focus prevents reappearance");visit.TogglePause(now+101);var before=r.X;visit.Tick(now+200,1);Check(r.X==before&&visit.Paused,"pause freezes simulation");visit.TogglePause(now+201);Check(!visit.Paused&&r.Hidden,"resume preserves hiding");
var survivor=new Game(100){EnableEncounters=false};survivor.Tick(101,0);survivor.Tick(126,0);Check(survivor.State.Residents.Count==1&&survivor.State.Residents[0].Kind==Kind.Baby,"survivor returns");
for(int i=0;i<100;i++)survivor.Spawn(Kind.Adult,127);Check(survivor.State.Residents.Count==38,"population cap");
Console.WriteLine("All Windows gameplay model tests passed on this host.");

var h=new Habitat();Check(h.Opened("a",100).Count==2,"first folder use");for(int i=0;i<8;i++)h.Opened("a",101+i);Check(h.Opened("a",120).Count==0,"frequently used folder stays clean");Check(h.Opened("a",86500).Count>=2,"neglected folder grows again");h.Clean(86501);Check(h.Opened("b",86502).Count==0,"scan protection");
var f=new Rectangle(100,100,800,500);for(int i=0;i<4;i++){var p=Habitat.Border(f,i,.5);Check(p.X+55==f.Left||p.X+55==f.Right||p.Y+85==f.Top||p.Y+85==f.Bottom,"window border "+i);}
var clean=new Game(100){EnableEncounters=false};clean.State.Xp=28;clean.State.Progression.Owned=Enum.GetValues<Tool>().ToList();var stain=clean.Spawn(Kind.Stain,100);clean.Spawn(Kind.Egg,100);clean.Scan(101);clean.Tick(160,1);Check(clean.State.Residents.Count==1&&clean.State.Residents[0]==stain,"scan preserves manual stain cleanup and prevents growth");

var slow=new Game(100){EnableEncounters=false};slow.State.Habitat.Rate=.25;slow.Spawn(Kind.Egg,100);var fast=new Game(100){EnableEncounters=false};fast.State.Habitat.Rate=3;fast.Spawn(Kind.Egg,100);for(int i=1;i<=20;i++){slow.Tick(100+i,1);fast.Tick(100+i,1);}Check(slow.State.Residents.Any(r=>r.Kind==Kind.Egg)&&fast.State.Residents.Any(r=>r.Kind==Kind.Baby),"growth rate changes hatch time, not walking speed");

var economy=new Game(100){EnableEncounters=false};economy.State.Xp=100;Check(!economy.Owns(Tool.Poison),"XP no longer buys tools");economy.State.Progression.Shells=4;economy.Select(Tool.Poison);Check(economy.Owns(Tool.Poison)&&economy.State.Progression.Shells==0,"shell purchase");economy.Select(Tool.Poison);Check(economy.State.Progression.Shells==0,"no repeat purchase");var gold=economy.Spawn(Kind.Gold,100)!;economy.Select(Tool.Pinch);economy.Use(gold.Id,101,1);economy.Use(gold.Id,102,1);Check(economy.State.Progression.Shells==2,"gold gives exactly one reward");var friend=economy.Spawn(Kind.Mouse,100)!;economy.Use(friend.Id,102,1);Check(friend.Kind==Kind.Mouse,"friends cannot be killed with tools");
var guests=new Game(100);guests.Tick(101,179);Check(!guests.State.Residents.Any(r=>r.Friend),"friends stay locked before time threshold");guests.Tick(102,1);Check(guests.State.Residents.Any(r=>r.Kind==Kind.Mouse),"mouse unlocks at 3 minutes");guests.Tick(103,420);Check(guests.State.Progression.Seen.Contains("CatPaw"),"cat paw unlocks at 10 minutes");for(int i=0;i<50;i++)guests.Tick(104+i*10,.1);Check(guests.State.Residents.Count(r=>r.Kind==Kind.Mouse)<=2&&guests.State.Residents.Count(r=>r.Kind==Kind.CatPaw)<=1,"rare friend population caps");
var legacy=System.Text.Json.Nodes.JsonNode.Parse(economy.Serialize())!;legacy.AsObject().Remove("Progression");var migrated=new Game(100);migrated.Restore(legacy.ToJsonString());Check(migrated.Owns(Tool.Cleaner),"legacy XP tools survive migration");

Check(Rules.PawContact(0)==0&&Rules.PawContact(3)==1&&Rules.PawContact(6)==0,"paw reach, planted hold, withdrawal");
var pawGame=new Game(100){EnableEncounters=false};var paw=pawGame.Spawn(Kind.CatPaw,100)!;paw.Hidden=false;paw.X=400;paw.Y=200;pawGame.Tick(103,3);Check(paw.X==400&&paw.Y==200&&!paw.Hidden,"paw remains anchored on desktop");pawGame.Tick(106,3);Check(!pawGame.State.Residents.Contains(paw),"paw withdraws after six seconds");
