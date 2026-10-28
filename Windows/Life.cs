using System.Text;
using System.Text.Json;
namespace Gala;

public class Bond
{
    public string Kind { get; set; } = "adult";
    public string Name { get; set; } = "";
    public int Trust
    {
        get; set;
    }
    public int Fear
    {
        get; set;
    }
    public bool Partner
    {
        get; set;
    }
    public bool Adopted
    {
        get; set;
    }
    public double LastInteraction { get; set; } = -100;
    public bool Protected => Partner || Adopted || Name.Length > 0;
}
public class NoteItem
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Text { get; set; } = "";
    public bool Done
    {
        get; set;
    }
}
public record Adoption(int version, string token, string kind, string name);
public class Life
{
    public Dictionary<string, Bond> Bonds { get; set; } = [];
    public Dictionary<string, double> Cards { get; set; } = [];
    public int Kills
    {
        get; set;
    }
    public List<string> GoldPaid { get; set; } = [];
    public List<NoteItem> Notes { get; set; } = [];
    public List<string> Received { get; set; } = [];
    public double FocusRemaining
    {
        get; set;
    }
    public bool TraceReady
    {
        get; set;
    }
    public double TraceClock
    {
        get; set;
    }
    public bool SafeLeft
    {
        get; set;
    }
    public string GuardSide { get; set; } = "";
    public double GuardUntil
    {
        get; set;
    }
    public static readonly (string Id, string Name)[] Achievements = [("combat.first", "第一回合"), ("combat.three",
        "三只了！"), ("gold.first", "金光一闪"), ("meet.mouse", "有鼠来访"), ("meet.cat", "谁把爪子放这了"), ("touch.mouse", "摸到小老鼠"),
        ("touch.cat", "软乎乎的爪背"), ("bond.roach", "我的第一位室友"), ("bond.mouse", "巡逻员报到"), ("bond.cat", "猫咪认得你了"),
        ("name.roach", "你有名字啦"), ("feed.first", "请你吃一口"), ("stash.first", "替我收好"), ("stash.return", "还真给我找回来了"),
        ("trace.first", "顺着脚印"), ("nest.first", "原来住在这里"), ("patrol.first", "今天有人值班"), ("guard.first", "大爪子镇场"),
        ("coexist.first", "大家都有地方住"), ("focus.first", "约好了，先安静"), ("adoption.first", "新室友远道而来"), ("share.first",
        "带着故事出发")];
    public static string KindName(Kind k) => k == Kind.CatPaw ? "catPaw" : k.ToString().ToLowerInvariant();
    public void Award(string key, double now)
    {
        Cards.TryAdd(key, now);
    }
    public void Observe(Resident r, double now)
    {
        Bonds.TryAdd(r.Id.ToString(), new()
        {
            Kind = KindName(r.Kind)
        });
        if (r.Kind == Kind.Mouse)
            Award("meet.mouse", now);
        if (r.Kind == Kind.CatPaw)
            Award("meet.cat", now);
    }
    public bool Protects(Guid id) => Bonds.TryGetValue(id.ToString(), out var b) && b.Protected;
    public int Gold(Guid id, double now)
    {
        string key = id.ToString();
        if (GoldPaid.Contains(key))
            return 0;
        GoldPaid.Add(key);
        Award("gold.first", now);
        return 2;
    }
    public void Defeat(double now)
    {
        Kills++;
        if (Kills >= 1)
            Award("combat.first", now);
        if (Kills >= 3)
            Award("combat.three", now);
    }
    public string Interact(Resident r, string action, string text, double now)
    {
        Observe(r, now);
        var b = Bonds[r.Id.ToString()];
        if (action == "name")
        {
            string name = text.Trim();
            if (name.Length == 0 || name.Length > 24)
                return "名字需为 1–24 字";
            b.Name = name;
            if (!r.Friend)
                Award("name.roach", now);
            return "名字已记住，住客保护已开启";
        }
        if (action == "bond")
        {
            if (b.Trust < 6)
                return "它还在试着认识你，再相处一阵吧";
            if (b.Partner)
                return "已经是伙伴啦";
            if (Bonds.Values.Count(b => b.Partner) >= 6)
                return "伙伴位已满（6 位）";
            b.Partner = true;
            Award(r.Kind == Kind.Mouse ? "bond.mouse" : r.Kind == Kind.CatPaw ? "bond.cat" : "bond.roach", now);
            return "伙伴入住！它会记得你，也会受到保护";
        }
        if (now - b.LastInteraction < 20)
            return "它还在享受刚才的互动，稍等一会儿";
        b.LastInteraction = now;
        b.Trust++;
        b.Fear = Math.Max(0, b.Fear - 1);
        if (action == "feed")
            Award("feed.first", now);
        if (action == "pet" && r.Kind == Kind.Mouse)
            Award("touch.mouse", now);
        if (action == "pet" && r.Kind == Kind.CatPaw)
            Award("touch.cat", now);
        return "它认得你的手了 ♡";
    }
    public string Stash(string text, double now)
    {
        if (!Bonds.Values.Any(b => b.Trust >= 2 || b.Adopted))
            return "先和一位住客熟悉起来，它就愿意替你收着";
        text = text.Trim();
        if (text.Length == 0 || text.Length > 4000 || Notes.Count >= 100)
            return "输入 1–4000 字，收纳上限 100 条";
        Notes.Add(new()
        {
            Text = text
        });
        Award("stash.first", now);
        return "纸条已收进窝里；随时可从清单取回";
    }
    public string? Share(Guid id, double now)
    {
        if (!Bonds.TryGetValue(id.ToString(), out var b) || !b.Protected)
            return null;
        var c = new Adoption(1, Guid.NewGuid().ToString(), b.Kind, b.Name);
        Award("share.first", now);
        return "GALA1:" + Convert.ToBase64String(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(c)));
    }
    public (Resident? Resident, string Message) Adopt(string code, double now)
    {
        try
        {
            if (code.Length >= 4096 || !code.StartsWith("GALA1:"))
                return (null, "领养码无效");
            var c = JsonSerializer.Deserialize<Adoption>(Convert.FromBase64String(code[6..]));
            if (c == null || c.version != 1 || !Guid.TryParse(c.token, out _) || c.name == null ||
                c.name.Length > 24 || !Enum.TryParse<Kind>(c.kind, true, out var kind) ||
                kind is not (Kind.Adult or Kind.Baby or Kind.Gold or Kind.Mouse or Kind.CatPaw))
                return (null, "领养码无效或版本不支持");
            if (Received.Contains(c.token.ToLowerInvariant()))
                return (null, "这个领养码已经接收过了");
            var r = new Resident { Kind = kind, Born = now };
            Received.Add(c.token.ToLowerInvariant());
            Observe(r, now);
            Bonds[r.Id.ToString()] = new()
            {
                Kind = c.kind,
                Name = c.name,
                Adopted = true
            };
            if (kind == Kind.Gold)
                GoldPaid.Add(r.Id.ToString());
            Award("adoption.first", now);
            return (r, "新室友入住；本地信任从零开始");
        }
        catch (Exception e) when (e is FormatException or JsonException or ArgumentException)
        {
            return (null, "领养码无效");
        }
    }
    public bool Tick(double dt, double now)
    {
        dt = Math.Clamp(dt, 0, 1);
        if (FocusRemaining > 0)
        {
            FocusRemaining = Math.Max(0, FocusRemaining - dt);
            if (FocusRemaining == 0)
            {
                Award("focus.first", now);
                return true;
            }
            return false;
        }
        return false;
    }
}
