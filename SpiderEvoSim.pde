import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Callable;
import java.util.concurrent.Future;
import com.jogamp.newt.opengl.GLWindow;
import processing.sound.*;
import java.util.HashSet;
import java.util.Set;


int CENTER_X = 960; // try setting this to 960 or 961 if there is horizontal camera-pan-drifting
String[] soundFileNames = {"slap0.wav","slap1.wav","slap2.wav","splat0.wav","splat1.wav","splat2.wav","boop1.wav","boop2.wav","jump.wav","news.wav"};
SoundFile[] sfx;
Room room;
Player player;
KeyHandler keyHandler;
int DIM_COUNT = 3;
int SPIDER_ITER_BUCKETS = 4;
float SWAT_SPEED = 0.001;
int R = 40;
int STEPS_CYCLE = 3;
int SIBSC = SPIDER_ITER_BUCKETS*STEPS_CYCLE;
Spider highlight_spider;
ArrayList<Spider> spiders;
ArrayList<Swatter> swatters;
int frames = 0;
int ticks = 0;
int totalIndex = 0;
int totalSwatterIndex = 0;
float[] camera = {0,0};
float EPS = 0.04;
PGraphics g;
int playback_speed = 1;
int dailyDeaths = 0;
int swattersSeenTotal = 0;
float TICKS_PER_DAY = 10000.0f;  // Keep as float but use explicit f suffix
float PER_DAY = 10000.0f;
boolean TRAP_MOUSE = true;
boolean lock_highlight = false;

GLWindow r;

int LEG_COUNT = 4;
int GENES_PER_LEG = STEPS_CYCLE*4+1; //13
int GENOME_LENGTH = LEG_COUNT*GENES_PER_LEG;

color WALL_COLOR = color(255,200,150);
color FLOOR_COLOR = color(155,170,185);
color SKY_COLOR = color(150,200,255);
ArrayList<Button> buttons = new ArrayList<Button>(0);

int STAT_COUNT = 6;
ArrayList<Float[]> stats = new ArrayList<Float[]>(0);
ArrayList<String> statNotes = new ArrayList<String>(0);
PGraphics[] statImages = new PGraphics[STAT_COUNT];

ArrayList<Window> windows = new ArrayList<Window>(0);
int WINDOW_COUNT = 15;
float WINDOW_W = 200;
float WINDOW_H = 100;
PImage[] windowImages;
int CHANGE_WINDOWS_EVERY = 500;

float sig(float a){
  return 1/(1+exp(-a));
}
float sig_inv(float a){
  return log(a/(1-a));
}
float ticksToDays(long age) {
    return age / TICKS_PER_DAY;
}
color darken(color c, float perc){
    float newR = red(c)*perc;
    float newG = green(c)*perc;
    float newB = blue(c)*perc;
    return color(newR, newG, newB);
  }
float[] mutate(float[] input, float mutation_rate){
  float[] result = new float[input.length];
  for(int i = 0; i < input.length; i++){
    float mutation = random(-mutation_rate,mutation_rate);
    result[i] = sig(sig_inv(input[i])+mutation);
  }
  return result;
}
float[] deepCopy(float[] input){
  float[] result = new float[input.length];
  for(int i = 0; i < input.length; i++){
    result[i] = input[i];
  }
  return result;
}
float[][] deepCopy(float[][] input){
  float[][] result = new float[input.length][input[0].length];
  for(int i = 0; i < input.length; i++){
    for(int j = 0; j < input[i].length; j++){
      result[i][j] = input[i][j];
    }
  }
  return result;
}

// Helper function to safely handle large numbers
double safeAdd(double a, double b) {
    double result = a + b;
    if (result == Double.POSITIVE_INFINITY || result == Double.NEGATIVE_INFINITY) {
        println("Warning: Arithmetic overflow in calculations");
        return Double.MAX_VALUE;
    }
    return result;
}
ArrayList<Spider> createSpiders(Room room) {
    int START_SPIDER_COUNT = 300;
    ArrayList<Spider> result = new ArrayList<Spider>();

    // Create a thread pool with a fixed number of threads
    ExecutorService executor = Executors.newFixedThreadPool(4);
    ArrayList<Future<Spider>> futureSpiders = new ArrayList<Future<Spider>>();

    for (int s = 0; s < START_SPIDER_COUNT; s++) {
        final int spiderIndex = s;  // Final or effectively final for lambda use
        futureSpiders.add(executor.submit(() -> new Spider(spiderIndex, room)));
    }

    // Collect results
    for (Future<Spider> future : futureSpiders) {
        try {
            result.add(future.get());  // Blocks until the thread completes
        } catch (Exception e) {
            e.printStackTrace();  // Handle exception
        }
    }

    // Shut down the executor service
    executor.shutdown();

    return result;
}

void createSwatters(Room room, int START_SPIDER_COUNT) {
    swatters = new ArrayList<Swatter>();

    ExecutorService executor = Executors.newFixedThreadPool(4);
    ArrayList<Future<Swatter>> futureSwatters = new ArrayList<Future<Swatter>>();

    for (int s = 0; s < START_SPIDER_COUNT; s++) {
        final int swatterIndex = s;
        float perc = (s + 0.5f) / START_SPIDER_COUNT * 1.4f - 0.4f;
        futureSwatters.add(executor.submit(() -> new Swatter(swatterIndex, perc, room, swatters)));
    }

    for (Future<Swatter> future : futureSwatters) {
        try {
            swatters.add(future.get());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    executor.shutdown();
}

void setup(){
  windowImages = new PImage[WINDOW_COUNT];
  for(int w = 0; w < WINDOW_COUNT; w++){
    windowImages[w] = loadImage("windows/w"+nf(w+1,4,0)+".png");
  }
  sfx = new SoundFile[soundFileNames.length];
  for(int s = 0; s < soundFileNames.length; s++){
    sfx[s] = new SoundFile(this, "audio/"+soundFileNames[s]);
  }
  
  float[][] walls = {{0,0},{975,0},{975,670},{1100,670},{1100,0},{2100,0},{2100,1000},{1100,1000},{1100,780},{975,780},{975,1000},{0,1000}};
  float[] zs = {0,500};
  float[] player_coor = {700,700,0,0};
  room = new Room(walls,zs);
  player = new Player(player_coor);
  spiders = createSpiders(room);
  createSwatters(room, 0);
  keyHandler = new KeyHandler();
  size(1920,1080,P3D);
  
  buttons.add(new Button(0,1300,300,"Increase"));
  buttons.add(new Button(1,1450,300,"Decrease"));
  
  buttons.add(new Button(2,1800,300,"Enlarge,Swatters"));
  buttons.add(new Button(3,1950,300,"Shrink,Swatters"));
  
  buttons.add(new Button(4,1800,700,"Speed up,Swatters"));
  buttons.add(new Button(5,1950,700,"Slow down,Swatters"));
  
  buttons.add(new Button(6,1450,700,"Invent,Swatters"));
  
  for(int d = 0; d < STAT_COUNT; d++){
    statImages[d] = createGraphics(800,600);
  }
  
  r = (GLWindow)surface.getNative();
  r.confinePointer(true);
  r.setPointerVisible(false);
  g = createGraphics(1920,1080,P3D);
}
void draw() {
    doMouse();
    doPhysics();
    drawVisuals();
    image(g, 0, 0);
    drawUI();
    frames++;    
    if (camera[1] < -1) {
        camera[1] = -1;
    }
    if (camera[1] > 1) {
        camera[1] = 1;
    }
}
void checkHighlight(){
  if(!lock_highlight){
    highlight_spider = checkHighlightHelper();
  }
}
Spider checkHighlightHelper(){
  Spider answer = null;
  float recordLowest = 1;
  if (mousePressed) {
    for (int s = 0; s < spiders.size(); s++) {
      float score = spiders.get(s).cursorOnSpider();
      if (score > 0 && score < recordLowest) {
        recordLowest = score;
        answer = spiders.get(s);
      }
    }
  }
  return answer;
}

void drawUI(){
  noStroke();
  fill(0);
  float M = 1;
  float W = 20;
  rect(width/2-M,height/2-W,M*2,W*2);
  rect(width/2-W,height/2-M,W*2,M*2);
  if(highlight_spider != null){
    PGraphics genomePanel = highlight_spider.drawGenome();
    image(genomePanel,width-genomePanel.width-30,height-genomePanel.height-30);
  }
  textAlign(LEFT);
  textSize(50);
  text(ticksToDate(ticks),20,65);
}

String dateNumToMonthString(int d) {
    String[] monthNames = {"January","February","March","April","May","June",
                          "July","August","September","October","November","December"};
    int[] monthDays = {31,28,31,30,31,30,31,31,30,31,30,31};
    
    // Bounds check
    if (d < 0) {
        println("Warning: Negative date value");
        return monthNames[0] + " 1";
    }
    
    int totalDays = 0;
    for (int m = 0; m < 12; m++) {
        if (d < monthDays[m]) {
            return monthNames[m] + " " + (d + 1);
        }
        d -= monthDays[m];
    }
    return monthNames[11] + " " + monthDays[11];
}
String ticksToDate(long t) {
    float daysTotalFloat = ticksToDays(t) + 0.5f;
    int daysTotalInt = (int)daysTotalFloat;
    float timeOfDay = daysTotalFloat % 1.0f;
    
    // Add bounds checking
    if (daysTotalInt > 365_000_000) {  
        println("Warning: Date calculation overflow");
        return "Year MAX";
    }
    
    int years = daysTotalInt / 365;
    int days = daysTotalInt % 365;
    
    String[] TOD_LIST = {"Night","Sunrise","Morning","Afternoon","Sunset","Evening"};
    String TOD = TOD_LIST[(int)(timeOfDay * 6)];
    
    return "Year " + (years + 1) + ", " + dateNumToMonthString(days) + " - " + TOD;
}
void doMouse(){
  if(TRAP_MOUSE){
    if(frames >= 2){
      camera[0] += (mouseX-CENTER_X)*0.005;
      camera[1] += (mouseY-height/2)*0.005;
    }
    r.warpPointer(width/2,height/2);
  }
}
void keyPressed(){
  keyHandler.handle(keyCode,true);
}
void keyReleased(){
  keyHandler.handle(keyCode,false);
}
void mousePressed() {
  g.pushMatrix();
  g.translate(width/2,height/2,0);
  player.snapCamera();
  Spider answer = checkHighlightHelper();
  if(answer == null){
    lock_highlight = false;
  }else{
    highlight_spider = answer;
    lock_highlight = true;
  }
  g.popMatrix();
}
void doPhysics(){
  iterateButtons(player);
  for(int p = 0; p < playback_speed; p++){
    iterateSpiders(room);
    iterateSwatters(room);
    collectData();
    ticks++;
  }
  player.takeInputs(keyHandler);
  player.doPhysics(room);
}

float getBiodiversity(){
  float[] meanGenome = new float[GENOME_LENGTH];
  for(int g = 0; g < GENOME_LENGTH; g++){
    meanGenome[g] = 0;
  }
  for(int s = 0; s < spiders.size(); s++){
    for(int g = 0; g < GENOME_LENGTH; g++){
      meanGenome[g] += spiders.get(s).genome[g];
    }
  }
  for(int g = 0; g < GENOME_LENGTH; g++){
    meanGenome[g] /= spiders.size();
  }
  float[] variances = new float[GENOME_LENGTH];
  for(int g = 0; g < GENOME_LENGTH; g++){
    variances[g] = 0;
  }
  for(int s = 0; s < spiders.size(); s++){
    for(int g = 0; g < GENOME_LENGTH; g++){
      variances[g] += pow(spiders.get(s).genome[g]-meanGenome[g],2);
    }
  }
  float total_diversity = 0;
  for(int g = 0; g < GENOME_LENGTH; g++){
    total_diversity += sqrt(variances[g]/spiders.size());
  }
  return total_diversity/GENOME_LENGTH*100;
}
void collectData() {
    if (ticks % CHANGE_WINDOWS_EVERY == 0) {
        for (int w = 0; w < windows.size(); w++) {
            windows.get(w).updateShow();
        }
    }
    if (ticks % (long)TICKS_PER_DAY == 0) {
        // Keep using Float[] to match Spider.writeData() method
        Float[] datum = new Float[STAT_COUNT];
        for (int d = 0; d < STAT_COUNT; d++) {
            datum[d] = 0.0f;  // Use 0.0f for Float
        }
        
        // Get spider count before division
        float spiderCount = spiders.size();
        
        for (int s = 0; s < spiders.size(); s++) {
            spiders.get(s).writeData(datum);
        }
        
        // Prevent division by zero and ensure precise division
        for (int d = 0; d < STAT_COUNT; d++) {
            datum[d] = spiderCount > 0 ? datum[d] / spiderCount : 0.0f;
        }
        
        datum[1] = (float)dailyDeaths;
        datum[2] = (float)(swattersSeenTotal - dailyDeaths);
        datum[4] = getBiodiversity();
        
        dailyDeaths = 0;
        swattersSeenTotal = 0;
        stats.add(datum);
        statNotes.add("");
        
        float[] graph_dim = {100, 120, 575, 400};
        String[] titles = {
            "Average Age (days)", 
            "Daily Deaths",
            "Daily Swatter Escapes", 
            "Sensitivity (out of 100)", 
            "Total Biodiversity (out of 100)", 
            "Average Swatters Seen"
        };
        
        for (int d = 0; d < STAT_COUNT; d++) {
            float[] graphData = new float[stats.size()];
            for (int i = 0; i < stats.size(); i++) {
                graphData[i] = stats.get(i)[d];
            }
            drawGraphOn(statImages[d], graphData, titles[d], graph_dim, color(128,0,0), d);
        }
        
        sfx[9].play();
        sfx[9].amp(1.0 - min(0.8, (playback_speed-1)/200.0));
    }
}
float getUnit(float a, float b){
  float diff = b-a;
  float[] units = {0.0001,0.0002,0.0005,0.001,0.002,0.005,0.01,0.02,0.05,0.1,0.2,0.5,1,2,5,10,20,50,100,200,500,1000,2000,5000,10000,20000,50000,100000,200000,500000,1000000};
  for(int u = 0; u < units.length; u++){
    if(units[u] >= diff*0.199){
      return units[u];
    }
  }
  return 1;
}
void drawGraphOn(PGraphics s, float[] data, String title, float[] graph_dim, color col, int d){
  s.beginDraw();
  s.background(255);
  float max = -9999999;
  float min = 9999999;
  for(int i = 0; i < data.length; i++){
    if(data[i] > max){
      max = data[i];
    }
    if(data[i] < min){
      min = data[i];
    }
  }
  if(max == min){
    max += 0.1;
  }
  float E_R = 15;
  s.strokeWeight(4);
  s.stroke(140);
  s.fill(140);
  s.textAlign(CENTER);
  float TS = 23;
  s.textSize(TS);
  for(int i = 0; i < data.length; i++){
    String str = statNotes.get(i);
    if(str.length() >= 1){
      String[] parts = str.split("-");
      float x = ((float)i)/data.length*graph_dim[2]+graph_dim[0];
      float y = graph_dim[1];
      float h = graph_dim[3];
      float y2 = y+h-parts.length*TS+3*TS;
      for(int j = 0; j < parts.length; j++){
        s.text(parts[j],x,y2+j*TS+TS);
      }
      s.line(x,y,x,y2);
    }
  }
  float unit = getUnit(min, max);
  float first_unit = floor(min/unit)*unit;
  s.textAlign(RIGHT);
  float TS2 = 36;
  s.textSize(TS2);
  s.strokeWeight(2);
  s.stroke(170);
  boolean INTEGER_MEASURE = (d == 1 || d == 2);
  for(float u = first_unit; u < max; u += unit){
    float x = graph_dim[0];
    float y = (1-(u-min)/(max-min))*graph_dim[3]+graph_dim[1];
    s.line(x,y,x+graph_dim[2],y);
    String str = nf(u,0,2);
    if(u%1.0 >= 0.999 || u%10 <= 0.001 || INTEGER_MEASURE){
      str = ""+(int)u;
    }
    s.text(str,x-10,y+TS*0.35);
  }
  s.strokeWeight(4);
  for(int i = 0; i < data.length; i++){
    float x = ((float)i)/data.length*graph_dim[2]+graph_dim[0];
    float y = (1-(data[i]-min)/(max-min))*graph_dim[3]+graph_dim[1];
    s.fill(col);
    if(data.length < 50){
      s.noStroke();
      s.ellipse(x,y,E_R,E_R);
    }
    if(i == data.length-1){
      float TS3 = (data[i] > 10 && !INTEGER_MEASURE) ? 39 : 50;
      s.textSize(TS3);
      s.textAlign(LEFT);
      String str =  INTEGER_MEASURE ? (int)data[i]+"" : nf(data[i],0,2);
      s.text(str,x+TS3*0.5,y+TS3*0.35);
      if(i >= 1){
        float delta = data[i]-data[i-1];
        String delta_str =  INTEGER_MEASURE ? (int)delta+"" : nf(delta,0,2);
        if(data[i] >= data[i-1]){
          delta_str = "+"+delta_str;
        }
        s.textSize(TS3*0.6);
        s.text(delta_str,x+TS3*0.5,y+TS3*1.1);
      }
    }else{
      float x2 = ((float)(i+1))/data.length*graph_dim[2]+graph_dim[0];
      float y2 = (1-(data[i+1]-min)/(max-min))*graph_dim[3]+graph_dim[1];
      s.stroke(col);
      s.line(x,y,x2,y2);
    }
  }
  s.textAlign(CENTER);
  s.fill(0);
  s.textSize(60);
  s.text(title,graph_dim[0]+graph_dim[2]*0.5,graph_dim[1]-50);
  s.endDraw();
}
float daylight() {
    float days = ticksToDays(ticks);
    if (Float.isInfinite(days) || Float.isNaN(days)) {
        println("Warning: Day calculation overflow in daylight()");
        return 0.5f;
    }
    return 0.5f + 0.5f * cos(days * (2 * PI));
}
void drawVisuals(){
  g.beginDraw();
  g.lights();
  g.background(darken(SKY_COLOR,daylight()));
  g.pushMatrix();
  g.translate(width/2,height/2,0);
  player.snapCamera();
  g.directionalLight(26, 51, 63, -0.934, -0.37, 0);
  g.directionalLight(26, 51, 63, 1.2, 0.55, 0);
  g.directionalLight(50, 50, 50, 0, 0, -1);
  room.drawWalls();
  player.drawPlayer();
  drawWindows();
  checkHighlight();
  drawSpiders(room);
  drawSwatters(room);
  drawButtons();
  g.popMatrix();
  g.endDraw();
}
void drawWindows(){
  for(int w = 0; w < windows.size(); w++){
    windows.get(w).drawWindow(room);
  }
}
void drawButtons(){
  for(int b = 0; b < buttons.size(); b++){
    buttons.get(b).drawButton();
  }
}
void aTranslate(float[] coor){
  g.translate(coor[0],coor[1],coor[2]);
}
void iterateSpiders(Room room){
  for(int s = 0; s < spiders.size(); s++){
    spiders.get(s).iterate(room, swatters, spiders);
  }
}
void iterateSwatters(Room room){
  for(int s = 0; s < swatters.size(); s++){
    swatters.get(s).iterate(room, spiders, swatters);
  }
}
void iterateButtons(Player player){
  for(int b = 0; b < buttons.size(); b++){
    buttons.get(b).iterate(player, room);
  }
}
void drawSpiders(Room room){
  for(int s = 0; s < spiders.size(); s++){
    spiders.get(s).drawSpider(room);
  }
}
void drawSwatters(Room room){
  for(int s = 0; s < swatters.size(); s++){
    swatters.get(s).drawSwatter(room);
  }
}
String commafy(double f) {
  String s = Math.round(f)+"";
  String result = "";
  for (int i = 0; i < s.length(); i++) {
    if ((s.length()-i)%3 == 0 && i != 0) {
      result = result+",";
    }
    result = result+s.charAt(i);
  }
  return result;
}
