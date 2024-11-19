import com.jogamp.newt.opengl.GLWindow;
import processing.sound.*;
import java.util.Arrays;

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
ArrayList<Spider> createSpiders(Room room){
  int START_SPIDER_COUNT = 300;
  ArrayList<Spider> result = new ArrayList<Spider>(0);
  for(int s = 0; s < START_SPIDER_COUNT; s++){
    Spider newSpider = new Spider(s, room);
    result.add(newSpider);
  }
  return result;
}
void createSwatters(Room room, int START_SPIDER_COUNT){
  swatters = new ArrayList<Swatter>(0);
  for(int s = 0; s < START_SPIDER_COUNT; s++){
    float perc = (s+0.5)/START_SPIDER_COUNT*1.4-0.4;
    Swatter newSwatter = new Swatter(s, perc, room, swatters);
    swatters.add(newSwatter);
  }
}

// Global variable to track loading status
boolean resourcesLoaded = false;

// Must be declared at the top level for Processing's size() to work
void settings() {
  size(1920,1080,P3D);
}
  
  void setup() {
  // Initialize core components first
  float[][] walls = {{0,0},{975,0},{975,670},{1100,670},{1100,0},{2100,0},{2100,1000},{1100,1000},{1100,780},{975,780},{975,1000},{0,1000}};
  float[] zs = {0,500};
  float[] player_coor = {700,700,0,0};
  room = new Room(walls,zs);
  player = new Player(player_coor);
  keyHandler = new KeyHandler();
  
  // Setup window
  r = (GLWindow)surface.getNative();
  r.confinePointer(true);
  r.setPointerVisible(false);
  g = createGraphics(1920,1080,P3D);
  
  // Start resource loading thread
  thread("loadResources");
}

void loadResources() {
  // Load windows in batches of 5
  windowImages = new PImage[WINDOW_COUNT];
  for(int w = 0; w < WINDOW_COUNT; w += 5) {
    int endIndex = min(w + 5, WINDOW_COUNT);
    for(int i = w; i < endIndex; i++) {
      windowImages[i] = loadImage("windows/w"+nf(i+1,4,0)+".png");
    }
  }
  
  // Load sound files in batches
  sfx = new SoundFile[soundFileNames.length];
  for(int s = 0; s < soundFileNames.length; s += 3) {
    int endIndex = min(s + 3, soundFileNames.length);
    for(int i = s; i < endIndex; i++) {
      sfx[i] = new SoundFile(this, "audio/"+soundFileNames[i]);
    }
  }
  
  // Initialize game objects
  spiders = createSpiders(room);
  createSwatters(room, 0);
  
  // Initialize buttons
  buttons.add(new Button(0,1300,300,"Increase"));
  buttons.add(new Button(1,1450,300,"Decrease"));
  buttons.add(new Button(2,1800,300,"Enlarge,Swatters"));
  buttons.add(new Button(3,1950,300,"Shrink,Swatters"));
  buttons.add(new Button(4,1800,700,"Speed up,Swatters"));
  buttons.add(new Button(5,1950,700,"Slow down,Swatters"));
  buttons.add(new Button(6,1450,700,"Invent,Swatters"));
  
  // Initialize stat images
  for(int d = 0; d < STAT_COUNT; d++){
    statImages[d] = createGraphics(800,600);
  }
  
  // Mark loading as complete
  resourcesLoaded = true;
}

//FPS counter
ArrayList<Long> frameTimestamps = new ArrayList<>(); // To store frame timestamps
float averageFps = 0; // Average FPS over the last 4 seconds

void draw() {
  if (!resourcesLoaded) {
    // Show loading screen
    background(0);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(32);
    text("Loading...", width/2, height/2);
    return;
  }  
  // Capture current time in milliseconds
    long currentTime = millis();
    frameTimestamps.add(currentTime);
    
    // Remove timestamps older than 4 seconds
    while (frameTimestamps.size() > 0 && frameTimestamps.get(0) < currentTime - 4000) {
        frameTimestamps.remove(0);
    }
    
    // Calculate average FPS
    if (frameTimestamps.size() > 1) {
        float elapsedSeconds = (frameTimestamps.get(frameTimestamps.size() - 1) - frameTimestamps.get(0)) / 1000.0f;
        averageFps = (frameTimestamps.size() - 1) / elapsedSeconds;
    }

    // Original draw logic
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

void drawUI() {
    noStroke();
    fill(0);
    float M = 1;
    float W = 20;
    rect(width / 2 - M, height / 2 - W, M * 2, W * 2);
    rect(width / 2 - W, height / 2 - M, W * 2, M * 2);
    
    if (highlight_spider != null) {
        PGraphics genomePanel = highlight_spider.drawGenome();
        image(genomePanel, width - genomePanel.width - 30, height - genomePanel.height - 30);
    }
    
    textAlign(LEFT);
    textSize(50);
    fill(255); // Set text color to white for visibility
    text(ticksToDate(ticks), 20, 65);
    
    // Display FPS
    textAlign(RIGHT);
    textSize(25);
    text("FPS: " + nf(averageFps, 0, 2), width - 20, 30); // Display the FPS in the top-right corner
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
    
    for (int m = 0; m < 12; m++) {
        if (d < monthDays[m]) {
            return monthNames[m] + " " + (d + 1);
        }
        d -= monthDays[m];
    }
    return monthNames[11] + " " + monthDays[11];
}

String ticksToDate(long t) { 
    // Convert ticks to days and add 0.5 for rounding, avoiding floating-point operations
    float daysTotal = ticksToDays(t) + 1;  // Add 1 instead of 0.5f for integer-based rounding
    if (daysTotal > 365_000_000L) {  
        println("Warning: Date calculation overflow");
        return "Year MAX";
    }

    // Calculate years and remaining days
    int years = (int)(daysTotal / 365);
    int days = (int)(daysTotal % 365);

    // Determine time of day using integer arithmetic
    int timeOfDayTicks = (int)(t % (24L * 60 * 60 * 1000)); // Ticks in one day
    int todIndex = (int)((timeOfDayTicks * 6L) / (24L * 60 * 60 * 1000)); // Map ticks to 0-5 range

    String[] TOD_LIST = {"Night", "Sunrise", "Morning", "Afternoon", "Sunset", "Evening"};
    String TOD = TOD_LIST[todIndex];

    // Construct the result string
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
        Window[] windowArray = windows.toArray(new Window[0]);
        for (Window window : windowArray) {
            window.updateShow();
        }
    }
    
    if (ticks % (long)TICKS_PER_DAY == 0) {
        // Pre-allocate arrays and reuse them
        Float[] datum = new Float[STAT_COUNT];
        Spider[] spiderArray = spiders.toArray(new Spider[0]);
        float spiderCount = spiderArray.length;
        
        // Initialize datum array more efficiently
        Arrays.fill(datum, 0.0f);
        
        // Process all spiders in a single pass
        for (Spider spider : spiderArray) {
            spider.writeData(datum);
        }
        
        // Batch process divisions
        if (spiderCount > 0) {
            float invCount = 1.0f / spiderCount;
            for (int d = 0; d < STAT_COUNT; d++) {
                datum[d] *= invCount;
            }
        }
        
        datum[1] = (float)dailyDeaths;
        datum[2] = (float)(swattersSeenTotal - dailyDeaths);
        datum[4] = getBiodiversity();
        
        // Store data and reset counters
        dailyDeaths = 0;
        swattersSeenTotal = 0;
        stats.add(datum);
        statNotes.add("");
        
        // Cache graph dimensions and titles
        final float[] GRAPH_DIM = {100, 120, 575, 400};
        final String[] TITLES = {
            "Average Age (days)", 
            "Daily Deaths",
            "Daily Swatter Escapes", 
            "Sensitivity (out of 100)", 
            "Total Biodiversity (out of 100)", 
            "Average Swatters Seen"
        };
        
        // Pre-allocate graph data array
        float[] graphData = new float[stats.size()];
        // Cache the color value
        color graphColor = color(128, 0, 0);
        
        // Draw all graphs with minimal object creation
        for (int d = 0; d < STAT_COUNT; d++) {
            for (int i = 0; i < stats.size(); i++) {
                graphData[i] = stats.get(i)[d];
            }
            drawGraphOn(statImages[d], graphData, TITLES[d], GRAPH_DIM, graphColor, d);
        }
        
        // Handle sound
        float amp = 1.0f - min(0.8f, (playback_speed-1)/200.0f);
        sfx[9].play();
        sfx[9].amp(amp);
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
void drawGraphOn(PGraphics s, float[] data, String title, float[] graph_dim, color col, int d) {
    // Pre-calculate frequently used values
    final float graphWidth = graph_dim[2];
    final float graphHeight = graph_dim[3];
    final float graphX = graph_dim[0];
    final float graphY = graph_dim[1];
    final int dataLength = data.length;
    
    // Find min/max in single pass
    float min = Float.MAX_VALUE;
    float max = -Float.MAX_VALUE;
    for (float value : data) {
        if (value > max) max = value;
        if (value < min) min = value;
    }
    if (max == min) max += 0.1;
    
    final float range = max - min;
    final float xScale = graphWidth / (dataLength - 1);
    final float yScale = graphHeight / range;
    
    s.beginDraw();
    s.background(255);
    
    // Batch similar operations together
    s.strokeWeight(4);
    s.stroke(140);
    s.fill(140);
    s.textAlign(CENTER);
    
    // Cache transformed coordinates
    float[] xCoords = new float[dataLength];
    float[] yCoords = new float[dataLength];
    for (int i = 0; i < dataLength; i++) {
        xCoords[i] = (i * xScale) + graphX;
        yCoords[i] = graphY + graphHeight * (1 - (data[i] - min) / range);
    }
    
    // Draw annotations in batch
    s.textSize(23);
    for (int i = 0; i < dataLength; i++) {
        String str = statNotes.get(i);
        if (str.length() >= 1) {
            String[] parts = str.split("-");
            float y2 = graphY + graphHeight - parts.length * 23 + 69; // 3 * 23
            
            // Draw line first
            s.line(xCoords[i], graphY, xCoords[i], y2);
            
            // Then all text
            for (int j = 0; j < parts.length; j++) {
                s.text(parts[j], xCoords[i], y2 + j * 23 + 23);
            }
        }
    }
    
    // Draw grid lines and values
    float unit = getUnit(min, max);
    float firstUnit = floor(min/unit) * unit;
    boolean integerMeasure = (d == 1 || d == 2);
    
    s.textAlign(RIGHT);
    s.textSize(36);
    s.strokeWeight(2);
    s.stroke(170);
    
    for (float u = firstUnit; u < max; u += unit) {
        float y = graphY + graphHeight * (1 - (u - min) / range);
        s.line(graphX, y, graphX + graphWidth, y);
        
        String str = integerMeasure ? String.valueOf((int)u) : 
                    (u % 1.0 >= 0.999 || u % 10 <= 0.001) ? String.valueOf((int)u) : nf(u, 0, 2);
        s.text(str, graphX - 10, y + 8); // 23 * 0.35 ≈ 8
    }
    
    // Draw data points and lines
    s.strokeWeight(4);
    s.fill(col);
    s.stroke(col);
    
    boolean showPoints = dataLength < 50;
    for (int i = 0; i < dataLength - 1; i++) {
        if (showPoints) {
            s.noStroke();
            s.ellipse(xCoords[i], yCoords[i], 15, 15);
            s.stroke(col);
        }
        s.line(xCoords[i], yCoords[i], xCoords[i + 1], yCoords[i + 1]);
    }
    
    // Draw final point and values
    if (dataLength > 0) {
        int last = dataLength - 1;
        float textSize = (data[last] > 10 && !integerMeasure) ? 39 : 50;
        s.textSize(textSize);
        s.textAlign(LEFT);
        
        String finalValue = integerMeasure ? String.valueOf((int)data[last]) : nf(data[last], 0, 2);
        s.text(finalValue, xCoords[last] + textSize * 0.5, yCoords[last] + textSize * 0.35);
        
        if (last > 0) {
            float delta = data[last] - data[last - 1];
            String deltaStr = (delta >= 0 ? "+" : "") + (integerMeasure ? String.valueOf((int)delta) : nf(delta, 0, 2));
            s.textSize(textSize * 0.6);
            s.text(deltaStr, xCoords[last] + textSize * 0.5, yCoords[last] + textSize * 1.1);
        }
    }
    
    // Draw title
    s.textAlign(CENTER);
    s.fill(0);
    s.textSize(60);
    s.text(title, graphX + graphWidth * 0.5, graphY - 50);
    
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
