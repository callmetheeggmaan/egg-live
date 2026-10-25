using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Collections.Generic;
using System.Windows.Forms;

[assembly: System.Reflection.AssemblyTitle("Egg LIVE")]
[assembly: System.Reflection.AssemblyProduct("Egg LIVE")]
[assembly: System.Reflection.AssemblyVersion("0.3.2.0")]

class Launcher : Form {
    const string Version = "0.3.2-beta.1";
    const string Url = "http://127.0.0.1:8790/";
    string root = AppDomain.CurrentDomain.BaseDirectory;
    Process owned;
    Label status;
    Button open;
    NotifyIcon tray;
    bool exiting;
    static readonly Color Bg=Color.FromArgb(12,16,23), Gold=Color.FromArgb(255,214,107);

    [STAThread] static int Main(string[] args) {
        if(args.Length>0 && args[0]=="--smoke-test") return Smoke();
        Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
        using(var mutex=new Mutex(false,"Local\\EggLiveLauncher")) {
            if(!mutex.WaitOne(0,false)) {Process.Start(Url+"#connection");return 0;}
            try{Application.Run(new Launcher());}finally{mutex.ReleaseMutex();}
        }
        return 0;
    }
    Launcher() {
        Text="Egg LIVE";ClientSize=new Size(550,340);BackColor=Bg;ForeColor=Color.White;
        Font=new Font("Segoe UI",10);FormBorderStyle=FormBorderStyle.FixedSingle;
        MaximizeBox=false;StartPosition=FormStartPosition.CenterScreen;
        try{Icon=new Icon(Path.Combine(root,"app","egg-live.ico"));}catch{}
        var brand=new Label{Text="EGG LIVE",Font=new Font("Segoe UI",32,FontStyle.Bold),ForeColor=Gold,AutoSize=true,Location=new Point(30,24)};
        var tagline=new Label{Text="Your stream. Their rules.",AutoSize=true,Location=new Point(34,91),ForeColor=Color.FromArgb(99,226,212)};
        status=new Label{Text="Starting your control room…",AutoSize=false,Location=new Point(34,137),Size=new Size(480,52)};
        open=new Button{Text="Open control room",Location=new Point(34,203),Size=new Size(300,46),BackColor=Gold,ForeColor=Bg,FlatStyle=FlatStyle.Flat,Enabled=false};
        open.Click+=(s,e)=>Process.Start(Url+"#connection");
        var exit=new Button{Text="Exit Egg LIVE",Location=new Point(347,203),Size=new Size(163,46),FlatStyle=FlatStyle.Flat,ForeColor=Color.White};
        exit.Click+=(s,e)=>ExitApp();
        var note=new Label{Text="LIVE beta • Connect only when you are ready.\nClosing this window keeps Egg LIVE in the system tray.",Location=new Point(34,271),Size=new Size(480,45),Font=new Font("Segoe UI",9),ForeColor=Color.FromArgb(153,166,186)};
        Controls.AddRange(new Control[]{brand,tagline,status,open,exit,note});
        tray=new NotifyIcon{Text="Egg LIVE",Icon=Icon,Visible=true};
        var menu=new ContextMenuStrip();menu.Items.Add("Open control room",null,(s,e)=>Process.Start(Url+"#connection"));menu.Items.Add("Show launcher",null,(s,e)=>{Show();WindowState=FormWindowState.Normal;Activate();});menu.Items.Add("Exit Egg LIVE",null,(s,e)=>ExitApp());tray.ContextMenuStrip=menu;
        tray.DoubleClick+=(s,e)=>{Show();Activate();};
        FormClosing+=(s,e)=>{if(!exiting){e.Cancel=true;Hide();}else tray.Dispose();};
        Shown+=async(s,e)=>await StartApp();
    }
    static Dictionary<string,object> State(string url) {
        var request=(HttpWebRequest)WebRequest.Create(url+"api/state");request.Timeout=700;request.Proxy=null;
        using(var response=request.GetResponse())using(var reader=new StreamReader(response.GetResponseStream()))
            return new JavaScriptSerializer{MaxJsonLength=4000000}.Deserialize<Dictionary<string,object>>(reader.ReadToEnd());
    }
    static Process Backend(string root,string port,string data) {
        string app=Path.Combine(root,"app");
        string node=Path.Combine(app,"runtime","node","node.exe"),python=Path.Combine(app,"runtime","python","python.exe");
        if(!File.Exists(node)||!File.Exists(python)||!File.Exists(Path.Combine(app,"companion","server.mjs")))throw new Exception("Extract the entire ZIP first. The app folder must stay beside Egg LIVE.exe.");
        var info=new ProcessStartInfo(node,"server.mjs"){WorkingDirectory=Path.Combine(app,"companion"),UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden};
        info.EnvironmentVariables["EGG_LIVE_PYTHON"]=python;
        info.EnvironmentVariables["EGG_LIVE_DATA"]=data;
        info.EnvironmentVariables["EGG_LIVE_ALLOW_LIVE"]="1";
        info.EnvironmentVariables["EGG_LIVE_TEST_TOOLS"]="0";
        info.EnvironmentVariables["PORT"]=port;
        return Process.Start(info);
    }
    async Task StartApp() {
        try {
            var existing=await Task.Run(()=>{try{return State(Url);}catch{return null;}});
            if(existing!=null) {
                if(!existing.ContainsKey("appId")||(string)existing["appId"]!="egg-live"||!existing.ContainsKey("version")||(string)existing["version"]!=Version)
                    throw new Exception("Another Egg LIVE version is running. Close the older version before opening this release.");
            } else {
                owned=Backend(root,"8790",Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Egg LIVE"));
                for(int i=0;i<60;i++){await Task.Delay(200);existing=await Task.Run(()=>{try{return State(Url);}catch{return null;}});if(existing!=null)break;if(owned.HasExited)throw new Exception("The control room could not start. Make sure port 8790 is free.");}
                if(existing==null)throw new Exception("The control room did not become ready.");
            }
            status.Text="Ready — open your control room to connect TikTok LIVE.";open.Enabled=true;
            Process.Start(Url+"#connection");
        } catch(Exception ex){status.Text=ex.Message;MessageBox.Show(this,ex.Message,"Egg LIVE",MessageBoxButtons.OK,MessageBoxIcon.Information);}
    }
    void ExitApp() {exiting=true;try{if(owned!=null&&!owned.HasExited)owned.Kill();}catch{} Close();}
    static int Smoke() {
        Process child=null;string root=AppDomain.CurrentDomain.BaseDirectory;
        try {
            child=Backend(root,"18791",Path.Combine(root,"launcher-smoke-data"));Dictionary<string,object> state=null;
            for(int i=0;i<60;i++){Thread.Sleep(200);try{state=State("http://127.0.0.1:18791/");break;}catch{}}
            if(state==null||(bool)state["testOnly"]||(bool)state["testTools"]||(string)state["version"]!=Version)throw new Exception("LIVE player mode was not enabled correctly.");
            var live=(Dictionary<string,object>)state["tiktok"];if((string)live["state"]!="disconnected")throw new Exception("Unexpected automatic LIVE connection.");
            File.WriteAllText(Path.Combine(root,"launcher-smoke-result.txt"),"PASS: bundled launcher starts LIVE-enabled, disconnected, player mode "+Version);return 0;
        }catch(Exception ex){File.WriteAllText(Path.Combine(root,"launcher-smoke-result.txt"),"FAIL: "+ex);return 1;}
        finally{try{if(child!=null&&!child.HasExited)child.Kill();}catch{}}
    }
}
