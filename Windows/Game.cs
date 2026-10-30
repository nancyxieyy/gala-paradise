using System.Text.Json;
using System.Text.Json.Serialization;
using System.Drawing;
namespace Gala;

public enum Tool
{
    Pinch, Slipper, Poison, Vacuum, Cleaner
}
public enum Kind
{
    Adult, Baby, Egg, Corpse, Stain, Gold, Mouse, CatPaw
}
public static class Rules
{
    public static readonly string[] Names = ["捏一下", "人字拖", "蟑螂药", "吸尘器", "清洁剂"];
    public static readonly int[] Cost = [0, 2, 4, 6, 5];
    public static readonly int[] Unlock = [0, 5, 12, 20, 28];
    public static readonly string[] Details = ["噗叽！会留奶油污渍", "啪！但它可能会飞", "药剂影响经过的旮杂", "活的、死的、卵，都能吸", "最后一步：把污渍擦掉"];
    public static double PawContact(double elapsed)
    {
        double t = Math.Clamp(elapsed < 1.2 ? elapsed / 1.2 : elapsed > 4.5 ? (6 - elapsed) / 1.5 : 1, 0, 1);
        return t * t * (3 - 2 * t);
    }
    public static int Canvas(Kind k) => k == Kind.CatPaw ? 252 : k == Kind.Mouse ? 182 : 110;
    public static float Size(Kind k) => k == Kind.Mouse ? 170 : k == Kind.CatPaw ? 240 : k == Kind.Baby ? 45 : k ==
        Kind.Egg ? 52 : 68;
}
public class Resident
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Kind Kind
    {
        get; set;
    }
    public float X
    {
        get; set;
    }
    public float Y
    {
        get; set;
    }
    [JsonIgnore]
    public double EggProgress
    {
        get; set;
    }
    [JsonIgnore] public double ResidueProgress { get; set; }
    [JsonIgnore] public bool EggDormant { get; set; }
    [JsonIgnore] public string EcologyIntent { get; set; } = "idle";
    [JsonIgnore]
    public double HoldUntil
    {
        get; set;
    }
    [JsonIgnore]
    public double ReactionUntil
    {
        get; set;
    }
    [JsonIgnore]
    public double CarryUntil
    {
        get; set;
    }
    public double Born
    {
        get; set;
    }
    [JsonIgnore]
    public Rectangle? EntryFrame
    {
        get; set;
    }
    [JsonIgnore]
    public double EntryUntil
    {
        get; set;
    }
    [JsonIgnore] public bool Friend => Kind is Kind.Mouse or Kind.CatPaw;
    [JsonIgnore] public bool Live => Kind is Kind.Adult or Kind.Baby or Kind.Gold || Friend;
    [JsonIgnore] public bool Hidden { get; set; } = true;
    [JsonIgnore]
    public bool Exiting
    {
        get; set;
    }
    [JsonIgnore]
    public double ExitAt
    {
        get; set;
    }
    [JsonIgnore]
    public double FlyingUntil
    {
        get; set;
    }
    [JsonIgnore]
    public double TauntUntil
    {
        get; set;
    }
    [JsonIgnore]
    public float TargetX
    {
        get; set;
    }
    [JsonIgnore]
    public float TargetY
    {
        get; set;
    }
    [JsonIgnore]
    public Rectangle Screen
    {
        get; set;
    }
    [JsonIgnore] public float Direction { get; set; } = 1;
}
public class SaveState
{
    public World? World
    {
        get; set;
    }
    public Life Life { get; set; } = new();
    public Progression Progression { get; set; } = new();
    public Habitat Habitat { get; set; } = new();
    public int Version { get; set; } = 1;
    public int Xp
    {
        get; set;
    }
    public int Captures
    {
        get; set;
    }
    public int Cleaned
    {
        get; set;
    }
    public int Fed
    {
        get; set;
    }
    public Tool Tool
    {
        get; set;
    }
    public bool Poisoned
    {
        get; set;
    }
    public bool Quiet
    {
        get; set;
    }
    public bool Explorer
    {
        get; set;
    }
    public List<Resident> Residents { get; set; } = [];
}
public partial class Game
{
    public BlindSession? Blind;
    public SaveState State = new();
    public Rectangle[] Screens = [new(0, 0, 1440, 900)];
    public bool Paused;
    public bool EnableEncounters = true;
    public string Message = "住客们正在角落躲着。";
    public double NextAppearance;
    double lastFeed = -10, lastFolder = -10, pauseStart;
    readonly Random rng;
    public int VisibleCount => State.Residents.Count(r => r.Live && !r.Hidden);
    public Game(double now, int? seed = null)
    {
        rng = seed.HasValue ? new Random(seed.Value) : new Random();
        NextAppearance = now + 8;
    }
    double Range(double a, double b) => a + rng.NextDouble() * (b - a);
    public bool Owns(Tool t) => State.Progression.Owned.Contains(t);
    public void Select(Tool t)
    {
        Blind?.Action("select");
        Blind?.Action(t.ToString().ToLowerInvariant());
        if (!Owns(t))
        {
            int cost = Rules.Cost[(int)t];
            if (State.Progression.Shells < cost)
            {
                Message = $"需要 {cost} 枚黄金卵壳，捕捉金色旮杂获得";
                return;
            }
            State.Progression.Shells -= cost;
            State.Progression.Owned.Add(t);
        }
        State.Tool = t;
        if (t == Tool.Poison)
            State.Poisoned = true;
        Message = $"已拿起{Rules.Names[(int)t]}，点击桌面上的目标";
    }
    public void Feed(double now)
    {
        if (Paused || State.Life.FocusRemaining > 0)
            return;
        if (now - lastFeed < 2)
        {
            Message = "嚼嚼嚼……稍等两秒再喂";
            return;
        }
        lastFeed = now;
        State.Xp += 3;
        State.Fed++;
        WorldSignal("food");
        Message = "面包屑 +3 生长点。旮杂：还有吗？";
    }
    public void Folder(double now, PointF? origin = null, string identity = "preview", Rectangle? frame = null)
    {
        if (Paused || State.Life.FocusRemaining > 0 || State.Quiet || now - lastFolder < 1.2)
            return;
        lastFolder = now;
        State.Xp++;
        string key = LocationKey(identity);
        if (frame.HasValue)
        {
            folderFrames[key] = frame.Value;
            if (folderFrames.Count > 64)
                folderFrames.Remove(folderFrames.Keys.Order().First());
        }
        WorldSignal("visit", location: key);
        Message = "角落里传来一点动静。";
    }

    public void Scan(double now)
    {
        if (!Owns(Tool.Poison))
        {
            Message = "兑换杀虫喷雾后，可使用全局扫描";
            return;
        }
        int count = State.Residents.RemoveAll(r => r.Kind != Kind.Stain && !r.Friend &&
            !State.Life.Protects(r.Id) && !(State.Life.SafeLeft && r.X < r.Screen.Left + r.Screen.Width / 2));
        State.Habitat.Clean(now);
        ReconcileWorld();
        foreach (var h in State.World!.habitats.ToArray())
            WorldSignal("clean", location: h.id);
        Message = $"清走 {count} 个住客／卵；污渍手动擦";
    }
    public Resident? Spawn(Kind k, double now, PointF? origin = null)
    {
        if (k is not (Kind.Corpse or Kind.Stain) && PopulationCount >= 38)
            return null;
        var f = Screens[rng.Next(Screens.Length)];
        var r = new Resident
        {
            Kind = k,
            Born = now,
            X = f.Left + (float)Range(10, Math.Max(11, f.Width - 110)),
            Y =
            f.Top + (float)Range(20, Math.Max(21, f.Height - 160)),
            Screen = f
        };
        if (k == Kind.Egg)
        {
            r.X = rng.Next(2) == 0 ? f.Left + 5 : f.Right - 95;
            r.Y = f.Bottom - (float)Range(140, 210);
        }
        if (origin.HasValue)
        {
            r.X = origin.Value.X;
            r.Y = origin.Value.Y;
        }
        r.Hidden = r.Live;
        State.Residents.Add(r);
        if (r.Live && (origin.HasValue || VisibleCount == 0))
            BeginVisit(r, now, origin);
        return r;
    }
    public void BeginVisit(Resident r, double now, PointF? origin = null)
    {
        if (State.Life.FocusRemaining > 0)
            return;
        var f = origin.HasValue ? Screens.FirstOrDefault(s => s.Contains(Point.Round(origin.Value)),
            Screens[0]) : Screens[rng.Next(Screens.Length)];
        r.Screen = f;
        int edge = rng.Next(4);
        r.X = edge == 0 ? f.Left - Rules.Canvas(r.Kind) : edge == 1 ? f.Right : f.Left + (float)Range(.2, .8) * f.Width;
        r.Y = edge == 2 ? f.Top - Rules.Canvas(r.Kind) : edge == 3 ? f.Bottom : f.Top + (float)Range(.2, .8) * f.Height;
        if (origin.HasValue)
        {
            r.X = origin.Value.X;
            r.Y = origin.Value.Y;
        }
        r.TargetX = f.Left + (float)Range(.25, .75) * f.Width;
        r.TargetY = f.Top + (float)Range(.2, .7) * f.Height;
        r.Hidden = false;
        r.Exiting = false;
        r.ExitAt = now + Range(9, 16);
    }
    public void Tick(double now, double dt)
    {
        if (State.Life.FocusRemaining > 0)
        {
            foreach (var r in State.Residents)
                r.Born += Math.Clamp(dt, 0, 1);
        }
        if (State.Life.Tick((Paused || State.Quiet) && State.Life.FocusRemaining <= 0 ? 0 : dt, now))
        {
            Message = "专注完成！大家等你回来";
            NextAppearance = now + 20;
        }
        if (Paused || State.Life.FocusRemaining > 0)
            return;
        State.Progression.Played += dt;

        foreach (var r in State.Residents.Where(r => r.Live))
        {
            if (r.Hidden)
                continue;
            if (!r.Friend && !State.Life.Protects(r.Id) && now < State.Life.GuardUntil && r.X >=
                r.Screen.Left + r.Screen.Width / 2)
            {
                r.Hidden = true;
                continue;
            }
            if (r.Screen.IntersectsWith(new System.Drawing.Rectangle((int)r.X, (int)r.Y, Rules.Canvas(r.Kind),
                Rules.Canvas(r.Kind))))
                State.Life.Observe(r, now);
            if (now < r.HoldUntil)
            {
                r.ExitAt += dt;
                if (r.Kind == Kind.CatPaw)
                    r.Born += dt;
                continue;
            }
            if (r.Kind == Kind.CatPaw)
            {
                if (now - r.Born >= 6)
                    r.Hidden = true;
                continue;
            }
            if (!r.Exiting && now >= r.ExitAt)
            {
                r.Exiting = true;
                var f = r.Screen;
                PointF[] exits = [new(f.Left - Rules.Canvas(r.Kind), r.Y), new(f.Right, r.Y), new(r.X,
                    f.Top - Rules.Canvas(r.Kind)), new(r.X, f.Bottom)];
                var p = exits.MinBy(p => MathF.Abs(p.X - r.X) + MathF.Abs(p.Y - r.Y));
                r.TargetX = p.X;
                r.TargetY = p.Y;
            }
            float dx = r.TargetX - r.X, dy = r.TargetY - r.Y, d = MathF.Sqrt(dx * dx + dy * dy);
            r.Direction = dx >= 0 ? 1 : -1;
            float step = (float)(dt * (r.Kind == Kind.Mouse ? 145 : r.Kind ==
                Kind.CatPaw ? 18 : r.FlyingUntil > now ? 190 : r.EcologyIntent ==
                "flee" ? 100 : 58) * (State.Quiet ? 0.4 : 1));
            if (d <= Math.Max(1, step))
            {
                r.X = r.TargetX;
                r.Y = r.TargetY;
                if (r.Exiting)
                {
                    r.Hidden = true;
                    NextAppearance = now + Range(22, 45);
                }
            }
            else
            {
                r.X += dx / d * step;
                r.Y += dy / d * step;
            }
        }
        State.Residents.RemoveAll(r => r.Friend && r.Hidden && !State.Life.Bonds.ContainsKey(r.Id.ToString()));
        if (State.Quiet)
            return;
        worldAccumulator += Math.Clamp(dt, 0, 2);
        if (worldAccumulator >= 2)
        {
            worldAccumulator -= 2;
            StepWorld(now);
        }
    }
    void SpawnFriend(Kind kind, double now)
    {
        var known = State.Residents.Find(r => r.Kind == kind && r.Hidden);
        if (known != null)
        {
            Summon(known, now);
            return;
        }
        var r = Spawn(kind, now);
        if (r == null)
            return;
        BeginVisit(r, now);
        var f = r.Screen;
        if (kind == Kind.Mouse)
        {
            r.X = f.Left - Rules.Canvas(r.Kind);
            r.Y = f.Bottom - 200;
            r.TargetX = f.Right;
            r.TargetY = r.Y;
            r.ExitAt = now + 14;
        }
        else
        {
            r.X = f.Right - 220;
            r.Y = f.Top + 200;
            r.Born = now;
        }
        if (!State.Progression.Seen.Contains(kind.ToString()))
        {
            State.Progression.Seen.Add(kind.ToString());
            Message = kind == Kind.Mouse ? "一只小老鼠路过。" : "边缘伸来一只猫爪。";
        }
    }
    public void TogglePause(double now)
    {
        Paused = !Paused;
        Blind?.Action(Paused ? "pause" : "resume");
        if (Paused)
            pauseStart = now;
        else
        {
            var d = now - pauseStart;
            foreach (var r in State.Residents)
            {
                r.Born += d;
                r.ExitAt += d;
                r.FlyingUntil += d;
                r.TauntUntil += d;
            }
            NextAppearance += d;
        }
        Message = Paused ? "全体暂停，可以安心办公" : "住客们回来啦";
    }
    public void Use(Guid id, double now, double? flightRoll = null)
    {
        Blind?.Action(State.Tool.ToString().ToLowerInvariant(), id.ToString(), time: State.World?.time ?? 0);
        var r = State.Residents.Find(r => r.Id == id);
        if (r == null || Paused || State.Life.FocusRemaining > 0)
            return;
        var t = State.Tool;
        if (!Owns(t))
            return;
        if (r.Friend || State.Life.Protects(r.Id) || (r.Live && State.Life.SafeLeft &&
            r.X < r.Screen.Left + r.Screen.Width / 2))
        {
            Message = PlayfulUse(r, t, now);
            return;
        }
        if (r.Live)
        {
            WorldSignal("threat", id);
            if (t == Tool.Poison)
            {
                WorldSignal("chemical", id);
                Message = "呲——";
                return;
            }
            if (t == Tool.Cleaner)
            {
                Message = "清洁剂只擦污渍，旮杂笑你了";
                return;
            }

            if (r.FlyingUntil > now && t != Tool.Vacuum)
            {
                Message = "嘿嘿，打不到～等落地或用吸尘器";
                return;
            }
            if ((r.Kind is Kind.Adult or Kind.Gold) && t != Tool.Vacuum && t != Tool.Poison &&
                (flightRoll ?? rng.NextDouble()) < .24)
            {
                State.Life.Observe(r, now);
                State.Life.Bonds[r.Id.ToString()].Fear++;
                r.FlyingUntil = now + 2.8;
                r.TauntUntil = now + 2.8;
                Message = "它居然起飞了！";
                return;
            }
            bool golden = r.Kind == Kind.Gold;
            if (golden)
                State.Progression.Shells += State.Life.Gold(r.Id, now);
            State.Captures++;
            State.Xp += 2;
            r.Hidden = false;
            if (t == Tool.Vacuum)
            {
                State.Residents.Remove(r);
                Message = "咻——吸走一只旮杂";
            }
            else
            {
                State.Life.Defeat(now);
                r.Kind = t == Tool.Pinch ? Kind.Stain : Kind.Corpse;
                r.Born = now;
                Message = t == Tool.Pinch ? "噗叽！得用清洁剂擦掉奶油污渍" : "啪！已躺平，用吸尘器收尾";
            }
            if (golden)
                Message = "获得 2 枚黄金卵壳 ✦ 点击锁定工具可兑换";
        }
        else if ((r.Kind == Kind.Stain && t == Tool.Cleaner) || ((r.Kind is Kind.Egg or Kind.Corpse) && t ==
            Tool.Vacuum))
        {
            State.Residents.Remove(r);
            State.Xp += 2;
            State.Cleaned++;
            Message = "清理完了……角落里呢？";
        }
        else
            Message = r.Kind == Kind.Stain ? "这是顽固污渍，要用清洁剂" : "用吸尘器收走吧";
    }
    public string PlayfulUse(Resident r, Tool tool, double now)
    {
        r.HoldUntil = now + 1.5;
        r.ReactionUntil = now + .55;
        if (r.Kind == Kind.CatPaw)
            r.Born = now - 2;
        if (tool == Tool.Pinch)
        {
            State.Life.Interact(r, "pet", "", now);
            WorldSignal("friendly", r.Id);
        }
        return tool switch
        {
            Tool.Pinch => r.Kind == Kind.CatPaw ? "呼噜～再摸一下 ♡" : "蹭蹭你的手 ♡",
            Tool.Slipper => r.Kind == Kind.CatPaw ? "啪！猫爪接住了拖鞋" : "嗖！侧身躲开，还回头看你",
            Tool.Poison => "阿嚏！抖掉泡沫，瞪你一眼",
            Tool.Vacuum => r.Kind == Kind.CatPaw ? "爪子按住吸嘴：不许吸！" : "呼——毛都吹乱啦！",
            _ => "擦擦脸，亮晶晶 ✦"
        };
    }
    public string Serialize() => JsonSerializer.Serialize(State, new JsonSerializerOptions { WriteIndented = true });
    public void Restore(string json)
    {
        State = JsonSerializer.Deserialize<SaveState>(json) ?? throw new InvalidDataException("空存档");
        if (!JsonDocument.Parse(json).RootElement.TryGetProperty("Progression", out _))
            State.Progression.Owned = Enum.GetValues<Tool>().Where(t => State.Xp >= Rules.Unlock[(int)t]).ToList();
        State.Habitat.Rate = new[] { .25, 1.0, 3.0 }.Contains(State.Habitat.Rate) ? State.Habitat.Rate : 1;
        State.Life.FocusRemaining = 0;
        State.Residents = State.Residents.Where(r => float.IsFinite(r.X) && float.IsFinite(r.Y)).ToList();
        LimitPopulation();
        if (!Enum.IsDefined(State.Tool) || !Owns(State.Tool))
            State.Tool = Tool.Pinch;
        foreach (var r in State.Residents)
            r.Hidden = r.Live;
    }
}
