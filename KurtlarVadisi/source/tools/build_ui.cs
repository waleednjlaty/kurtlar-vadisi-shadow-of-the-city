using System;using System.Drawing;using System.Drawing.Imaging;using System.Drawing.Text;using System.IO;
class BuildUi {
 static string dir;
 static void Card(string id,string top,string tr,string ar,bool title){
  int w=1400,h=title?400:240;
  using(var b=new Bitmap(w,h,PixelFormat.Format32bppArgb)) using(var g=Graphics.FromImage(b)){
   g.Clear(Color.Transparent);g.TextRenderingHint=TextRenderingHint.AntiAliasGridFit;
   using(var bg=new SolidBrush(Color.FromArgb(title?205:215,8,11,14)))g.FillRectangle(bg,0,0,w,h);
   using(var line=new SolidBrush(Color.FromArgb(190,159,110)))g.FillRectangle(line,0,0,w,3);
   var fmt=new StringFormat{Alignment=StringAlignment.Center,LineAlignment=StringAlignment.Center};
   using(var f=new Font("Tahoma",title?25:22,FontStyle.Bold))using(var br=new SolidBrush(Color.FromArgb(210,182,132)))g.DrawString(top,f,br,new RectangleF(30,12,w-60,title?65:50),fmt);
   using(var f=new Font("Tahoma",title?46:34,FontStyle.Regular))g.DrawString(tr,f,Brushes.White,new RectangleF(30,title?95:67,w-60,title?100:75),fmt);
   fmt.FormatFlags=StringFormatFlags.DirectionRightToLeft;
   using(var f=new Font("Tahoma",title?44:34,FontStyle.Regular))g.DrawString(ar,f,Brushes.White,new RectangleF(30,title?220:145,w-60,title?100:78),fmt);
   b.Save(Path.Combine(dir,id+".png"),ImageFormat.Png);
  }
 }
 static void Main(string[] a){dir=a[0];Directory.CreateDirectory(dir);
  Card("title","BÖLÜM I · VADİYE DÖNÜŞ","Geceye Dönüş","العودة إلى الليل",true);
  Card("memati_001","MEMATİ","Abi... üç aydır sessizler.","أخي... إنهم صامتون منذ ثلاثة أشهر.",false);
  Card("polat_001","POLAT ALEMDAR","Sessizlik bazen fırtınadan daha tehlikelidir Memati.","أحيانًا يكون الصمت أخطر من العاصفة يا ميماتي.",false);
  Card("wolves","","Kurtlar yeniden vadide.","الذئاب عادت إلى الوادي.",false);
  Card("objective","","Karargâha git.","اذهب إلى المقر.",false);
  Card("complete","MISSION COMPLETE","Geceye Dönüş","العودة إلى الليل",true);
  Card("envelope","","Selim Karahan","",false);
 }
}
