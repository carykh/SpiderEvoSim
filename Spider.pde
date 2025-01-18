class Spider{
  float BODY_SPAN = 4;
  float MAX_LEG_SPAN = 37;
  float Ldist = MAX_LEG_SPAN*0.25;
  int ITER_TIME = (int)random(0,SIBSC);
  
  float[] genome;
  float[] coor;
  float[][] leg_coor;
  int index;
  int visIndex;
  int generation;
  int birth_tick;
  Spider parent;
  ArrayList<Integer> swattersSeen = new ArrayList<Integer>(0); 
  
  public Spider(int i, Room room){
    parent = null;
    genome = new float[GENOME_LENGTH];
    for(int g = 0; g < GENOME_LENGTH; g++){
      genome[g] = random(0.2,0.4);
    }
    coor = new float[2];
    for(int d = 0; d < 2; d++){
      coor[d] = random(0,room.getMaxDim(d));
    }
    leg_coor = new float[LEG_COUNT][2];
    float ang = random(0,1);
    for(int L = 0; L < LEG_COUNT; L++){
      float angL = (L+ang)*PI/2;
      int genome_index = L*GENES_PER_LEG+1;
      float distance = genome[genome_index];
      leg_coor[L][0] = coor[0]+cos(angL)*distance;
      leg_coor[L][1] = coor[1]+sin(angL)*distance;
    }
    index = i;
    generation = 0;
    increment_();
  }
  float clip_(float val, Room room, int dim){
    float min_ = 0;
    float max_ = room.getMaxDim(dim);
    return min(max(val,min_),max_);
  }
  float cursorOnSpider(){
    float[] realCoor = room.wallCoor_to_realCoor(coor);
    g.pushMatrix();
    aTranslate(realCoor);
    float MAX_DIST_MOUSE = 100;
    float value = -99999;
    float x1 = g.screenX(0,0,0);
    float y1 = g.screenY(0,0,0);
    float x2 = g.screenX(0,MAX_LEG_SPAN,0);
    float y2 = g.screenY(0,MAX_LEG_SPAN,0);
    float distFromCenter = dist(x1,y1,width/2,height/2);
    if(distFromCenter < dist(x1,y1,x2,y2) && distFromCenter < MAX_DIST_MOUSE){
      value = g.screenZ(0,0,0);
    }
    g.popMatrix();
    return value;
  }
  color getColor(){
    int c = swattersSeen.size();
    if(c == 0){
      return color(0,0,0,255);
    } else {
      if(c <= 5){
        float fac = c/5.0;
        return color(0,fac*140,255-fac*255,255);
      } else {
        if (c <= 20) {
          float fac = (c-5)/15.0;
          return color(fac*255, 140+fac*155, 0, 255);
        } else {
           if (c <= 40) {
            float fac = (c-20)/20.0;
            return color (255, 255-fac*115, 0, 255);
          } else {
            if ( c <= 100) {
              float fac = (c-40)/60.0;
              return color (255, 140-fac*140, 0, 255);
            } else {
              if (c <= 200) {
                float fac = (c-100)/100.0;
                return color (255, 0, fac*255, 255);
              } else {
                if (c <= 500) {
                  float fac = (c-200)/100.0;
                  return color (255-fac*141, 0, 255, 255);
                } else {
                  if (c <= 1000) {
                    float fac = (c-500)/500.0;
                    return color (114-fac*114, fac*255,255, 255);
                  } else {
                    if (c <= 10000) {
                      float fac = (c-1000)/9000.0;
                      return color (fac*255, 255-fac*53, 255-fac*255);
                    } else {
                      float fac = min(1, (c-10000)/40000);
                      return color (255, 202+fac*53, fac*255);
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  color transitionColor(color a, color b, float prog){
    float newR = lerp(red(a), red(b), prog);
    float newG = lerp(green(a), green(b), prog);
    float newB = lerp(blue(a), blue(b), prog);
    return color(newR, newG, newB);
  }
  void drawSpider(Room room){
    color c = getColor();
    if(this == highlight_spider){
      c = color(0,255,0);
    }
    float[] realCoor = room.wallCoor_to_realCoor(coor);
    g.pushMatrix();
    aTranslate(realCoor);
    g.fill(c);
    g.pushMatrix();
    g.rotateZ(realCoor[3]);
    g.beginShape();
    for(int i = 0; i < 12; i++){
      float angle = i*2*PI/12;
      g.vertex(cos(angle)*BODY_SPAN,2,sin(angle)*BODY_SPAN);
    }
    g.endShape(CLOSE);
    g.popMatrix();
    
    g.stroke(c);
    g.strokeWeight(3);
    for(int L = 0; L < LEG_COUNT; L++){
      float[] legRealCoor = room.wallCoor_to_realCoor(leg_coor[L]);
      float[] Lcoor = aSubstract(legRealCoor,realCoor);
      float[] Mcoor = multi(Lcoor,0.5);
      Mcoor[0] -= sin(realCoor[3])*Ldist;
      Mcoor[1] += cos(realCoor[3])*Ldist;
      g.line(0,0,0,Mcoor[0],Mcoor[1],Mcoor[2]);
      g.line(Mcoor[0],Mcoor[1],Mcoor[2],Lcoor[0],Lcoor[1],Lcoor[2]);
    }
    g.noStroke();
    g.popMatrix();
    
    
    if(getAge() < 200 && parent != null && parent.getAge() >= getAge()){
      float[] parentCoor = room.wallCoor_to_realCoor(parent.coor);
      if(realCoor[0] == parentCoor[0] && realCoor[1] == parentCoor[1]){
        return;
      }
      g.pushMatrix();
      aTranslate(realCoor);
      g.rotateZ(realCoor[3]);
      g.beginShape();
      g.fill(255);
      float WHITE_SPAN = BODY_SPAN*4;
      for(int i = 0; i < 12; i++){
        float angle = i*2*PI/12;
        g.vertex(cos(angle)*WHITE_SPAN,EPS*2,sin(angle)*WHITE_SPAN);
      }
      g.endShape(CLOSE);
      g.popMatrix();
      
      if(dist(realCoor[0],realCoor[1],realCoor[2],parentCoor[0],parentCoor[1],parentCoor[2]) < WHITE_SPAN*10){
        g.stroke(255);
        g.strokeWeight(20);
        g.line(realCoor[0],realCoor[1],realCoor[2],parentCoor[0],parentCoor[1],parentCoor[2]);
        g.noStroke();
      }
    }
  }
  float[] multi(float[] a, float m){
    float[] result = new float[a.length];
    for(int i = 0; i < a.length; i++){
      result[i] = a[i]*m;
    }
    return result;
  }
  float[] aSubstract(float[] a, float[] b){
    float[] result = new float[a.length];
    for(int i = 0; i < a.length; i++){
      result[i] = a[i]-b[i];
    }
    return result;
  }
  float[] getWeightedCenter(int step, Room room, float darkest_sensed_shadow){
    float[] sum_coor = {0,0};
    float sum_weight = 0;
    for(int L = 0; L < LEG_COUNT; L++){
      int genome_index = L*GENES_PER_LEG+2*step;
      if(darkest_sensed_shadow < genome[L*GENES_PER_LEG+12]){ // it's below the threshold, so do the dark pattern
        genome_index += 6;
      }
      float weight = genome[genome_index];
      sum_weight += weight;
      for(int d = 0; d < 2; d++){
        sum_coor[d] += leg_coor[L][d]*weight;
      }
    }
    float rx = sum_coor[0]/sum_weight;
    float ry = sum_coor[1]/sum_weight;
    float[] result = {rx, ry};
    return result;
  }
  void placeLegs(float[] center, int step, Room room, float darkest_sensed_shadow, ArrayList<Spider> spiders){
    float force_to_right_angles = 0.001; // how strongly should the spider's legs be dragged back into right angles?
    float first_angle = 0;
    for(int L = 0; L < LEG_COUNT; L++){
      int genome_index = L*GENES_PER_LEG+2*step+1;
      if(darkest_sensed_shadow < genome[L*GENES_PER_LEG+12]){ // it's below the threshold, so do the dark pattern
        genome_index += 6;
      }
      float distance = genome[genome_index]*MAX_LEG_SPAN;
      float delta_x = leg_coor[L][0]-center[0];
      float delta_y = leg_coor[L][1]-center[1];
      float angle = atan2(delta_y,delta_x);
      if(L == 0){
        first_angle = angle;
      }else{
        float desired_angle = first_angle+PI/2*L;
        float move = (desired_angle-angle);
        while(move > PI){
          move -= 2*PI;
        }
        while(move < -PI){
          move += 2*PI;
        }
        angle += force_to_right_angles*move;
      }
      leg_coor[L][0] = center[0]+cos(angle)*distance;
      leg_coor[L][1] = center[1]+sin(angle)*distance;
    }
    coor = getWeightedCenter(step,room,darkest_sensed_shadow);
    for(int d = 0; d < 2; d++){
      if(coor[d] < 0){
        shiftAllBy(d,room.getMaxDim(d));
      }else if(coor[d] >= room.getMaxDim(d)){
        shiftAllBy(d,-room.getMaxDim(d));
      }
    }
  }
  void shiftAllBy(int dim, float amt){
    coor[dim] += amt;
    for(int L = 0; L < LEG_COUNT; L++){
      leg_coor[L][dim] += amt;
    }
  }
  void iterate(Room room, ArrayList<Swatter> swatters, ArrayList<Spider> spiders){
    int cycle = whereInCycle(0);
    if(cycle%SPIDER_ITER_BUCKETS == 0){
      move(room, cycle, swatters, spiders);
    }
  }
  float getDarkestShadow(){
    float darkest_sensed_shadow = 1.0;
    for(int s = 0; s < swatters.size(); s++){
      Swatter sw = swatters.get(s);
      float x = sw.coor[0];
      float y1 = sw.coor[1]-R;
      float y2 = sw.coor[1]+R;
      for(int L = 0; L < LEG_COUNT; L++){
        if(abs(leg_coor[L][0]-sw.coor[0]) < R && abs(leg_coor[L][1]-sw.coor[1]) < R){ // it's under the shadow!
          if(!swattersSeen.contains(sw.visIndex)){
            swattersSeen.add(sw.visIndex);
            swattersSeenTotal++;
          }
          darkest_sensed_shadow = min(darkest_sensed_shadow,max(sw.percentage,0));
        }
      }
    }
    return darkest_sensed_shadow;
  }
  void move(Room room, int cycle, ArrayList<Swatter> swatters, ArrayList<Spider> spiders){
    float darkest_sensed_shadow = getDarkestShadow();
    int step = cycle/SPIDER_ITER_BUCKETS;
    float[] weightedCenter = getWeightedCenter(step, room, darkest_sensed_shadow);
    placeLegs(weightedCenter, step, room, darkest_sensed_shadow, spiders);
  }
  int whereInCycle(int offset){
    return (ticks+offset-ITER_TIME+SIBSC)%SIBSC;
  }
  PGraphics drawGenome(){
    PGraphics panel = createGraphics(400,540);
    panel.beginDraw();
    panel.background(40,80,120);
    
    boolean[] shouldBeGreen = new boolean[GENOME_LENGTH];
    for(int g = 0; g < GENOME_LENGTH; g++){
      shouldBeGreen[g] = false;
    }
    int step = whereInCycle(0)/SPIDER_ITER_BUCKETS;
    int step2 = whereInCycle(SPIDER_ITER_BUCKETS/2)/SPIDER_ITER_BUCKETS;
    float darkest = getDarkestShadow();
    for(int L = 0; L < LEG_COUNT; L++){
      int index = L*13+step*2+1;
      int index2 = L*13+step2*2;
      float threshold = genome[L*13+12];
      if(darkest < threshold){
        shouldBeGreen[L*13+12] = true;
        index += 6;
        index2 += 6;
      }
      shouldBeGreen[index] = true;
      shouldBeGreen[index2] = true;
    }
    for(int g = 0; g < GENOME_LENGTH; g++){
      panel.fill(genome[g]*255);
      panel.stroke(0);
      panel.strokeWeight(1);
      if(shouldBeGreen[g]){
        panel.stroke(0,255,0);
        panel.strokeWeight(2);
      }
      float g1 = g%GENES_PER_LEG;
      float g2 = g/GENES_PER_LEG;
      float x;
      float y;
      if(g1 == 12){
        x = 185;
        y = 170;
      }else{
        x = 20*g1+10;
        y = 180-(g1%2)*40+10;
        if(g1 >= 6){
          x += 130;
        }
      }
      y += 100*g2;
      panel.rect(x,y,30,30);
    }
    panel.fill(255);
    panel.textAlign(LEFT);
    panel.textSize(30);
    panel.text("Spider #"+commafy(visIndex+1),20,40);
    panel.text("Generation #"+commafy(generation+1),20,70);
    panel.text("Age: "+nf(ticksToDays(getAge()),0,2)+" days",20,100);
    String p = (howManySwattersSeen() == 1) ? "" : "s";
    panel.text(commafy(howManySwattersSeen())+" swatter"+p+" seen",80,130);
    panel.fill(getColor());
    panel.stroke(0);
    panel.rect(20,109,50,25);
    panel.endDraw();
    return panel;
  }
  int howManySwattersSeen(){
    return swattersSeen.size();
  }
  void randomShift(){
    float dsx = random(-MAX_LEG_SPAN/2,MAX_LEG_SPAN/2);
    float dsy = random(-MAX_LEG_SPAN/2,MAX_LEG_SPAN/2);
    
    float dangle = random(0.1*PI,1.9*PI);
    for(int L = 0; L < LEG_COUNT; L++){
      float dx = leg_coor[L][0]-coor[0];
      float dy = leg_coor[L][1]-coor[1];
      float dist_ = dist(0,0,dx,dy);
      float angle = atan2(dy,dx);
      float newAngle = angle+dangle;
      float newDX = cos(newAngle)*dist_;
      float newDY = sin(newAngle)*dist_;
      leg_coor[L][0] = coor[0]+newDX+dsx;
      leg_coor[L][1] = coor[1]+newDY+dsy;
    }
    coor[0] += dsx;
    coor[1] += dsy;
  }
  void reincarnate(ArrayList<Spider> spiders){
    dailyDeaths++;
    parent = spiders.get((int)random(0,spiders.size()));
    float MUTATION_FACTOR = 0.2;
    genome = mutate(parent.genome, MUTATION_FACTOR);
    coor = deepCopy(parent.coor);
    leg_coor = deepCopy(parent.leg_coor);
    randomShift();
    generation = parent.generation+1;
    increment_();
  }
  int getAge(){
    return ticks-birth_tick;
  }
  void increment_(){
    visIndex = totalIndex;
    totalIndex++;
    birth_tick = ticks;
    swattersSeen = new ArrayList<Integer>(0); 
  }
  float getSensitivity(){
    float sensitivity = 0;
    for(int L = 0; L < LEG_COUNT; L++){
      for(int k = 0; k < 6; k++){
        sensitivity += abs(genome[L*13+k]-genome[L*13+6+k]);
      }
    }
    return sensitivity/LEG_COUNT/6*100;
  }
  void writeData(Float[] datum){
    datum[0] += ticksToDays(getAge());
    datum[3] += getSensitivity();
    datum[5] += swattersSeen.size();
  }
}
