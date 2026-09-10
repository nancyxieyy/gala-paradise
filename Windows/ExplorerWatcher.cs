using System.Runtime.InteropServices;
using System.Text;
namespace Gala;
// Read only the foreground Explorer window. No file contents or file mutations.
sealed class ExplorerWatcher:IDisposable {
    [DllImport("user32.dll")]static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern int GetClassName(IntPtr hwnd,StringBuilder name,int count);
    [DllImport("user32.dll")]static extern bool GetWindowRect(IntPtr hwnd,out NativeRect rect);
    [StructLayout(LayoutKind.Sequential)]struct NativeRect{public int Left,Top,Right,Bottom;}
    object? shell; string last="";
    public bool TryFolder(out PointF point,out string identity,out Rectangle frame){
        point=default;identity="";frame=default;IntPtr hwnd=GetForegroundWindow();var cls=new StringBuilder(128);GetClassName(hwnd,cls,128);if(cls.ToString() is not ("CabinetWClass" or "ExploreWClass")){last="";return false;}
        object? windows=null;
        try{
            shell??=Activator.CreateInstance(Type.GetTypeFromProgID("Shell.Application")!);
            windows=((dynamic)shell!).Windows();int count=(int)((dynamic)windows).Count;
            for(int i=0;i<count;i++){
                object? win=null;try{win=((dynamic)windows).Item(i);if(win==null)continue;
                    if((long)((dynamic)win).HWND!=hwnd.ToInt64())continue;
                    string url=(string)((dynamic)win).LocationURL;
                    if(string.IsNullOrEmpty(url))continue;
                    var key=hwnd.ToString()+"|"+url;if(key==last)return false;last=key;
                    identity=url;if(GetWindowRect(hwnd,out var r)){frame=Rectangle.FromLTRB(r.Left,r.Top,r.Right,r.Bottom);point=Habitat.Border(frame,0,.5);}return true;
                }finally{Release(win);}
            }
        }catch(COMException){Release(shell);shell=null;}catch{ /* Shell may be restarting or the current page may not be a folder. */ }
        finally{Release(windows);}return false;
    }
    static void Release(object? o){if(o!=null&&Marshal.IsComObject(o))Marshal.FinalReleaseComObject(o);}
    public void Dispose(){Release(shell);shell=null;}
}
