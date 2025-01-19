class Player{
  float[] coor;
  float[] lag_coor;
  float[] velo;
  float FRICTION = 0.85;
  float ACCEL = 1.8;
  float R_ACCEL = 0.05;
  float THICKNESS = 11;
  float EPS = 0.1;
  boolean accelerating = false;
  public Player(float[] _coor){
    coor = deepCopy(_coor);
    lag_coor = deepCopy(_coor);
    velo = newBlank();
  }
  float[] newBlank(){
    float[] result = {0,0,0,0};
    return result;
  }
  void drawPlayer(){
    float walk_swing = sin(millis()*0.04);
    float walk_swing2 = sin(millis()*0.052);
    float idle_swing = sin(millis()*0.003);
    boolean inAir = (coor[2] > 0);
    if(inAir){
      walk_swing = 0;
      walk_swing2 = 0;
      idle_swing = 0;
    }
    g.pushMatrix();
    g.translate(coor[0],coor[1],coor[2]);
    g.rotateZ(coor[3]);
    float[][] lines = {{0,4,0,2},{0,4,-1,2},{0,4,1,2},{0,2,1,0},{0,2,-1,0}};
    float SCALE_Y = 10;
    float SCALE_Z = 10;
    if(accelerating){
      SCALE_Z = 10+walk_swing2;
    }else{
      SCALE_Z = 10+0.26*idle_swing;
    }
    float W = 2;
    for(int i = 0; i < lines.length; i++){
      g.fill(50);
      g.beginShape();
      float dangleX = 0;
      if(i >= 1 && accelerating){
        dangleX = walk_swing*10;
        if(i == 2 || i == 3){
          dangleX *= -1;
        }
      }
      float flyMulti = 1.0;
      if(inAir){
        flyMulti *= (12-velo[2])*0.1;
      }
      g.vertex(dangleX,lines[i][2]*SCALE_Y*flyMulti-W,lines[i][3]*SCALE_Z);
      g.vertex(dangleX,lines[i][2]*SCALE_Y*flyMulti+W,lines[i][3]*SCALE_Z);
      g.vertex(0,lines[i][0]*SCALE_Y+W,lines[i][1]*SCALE_Z);
      g.vertex(0,lines[i][0]*SCALE_Y-W,lines[i][1]*SCALE_Z);
      g.endShape(CLOSE);
    }
    float HEAD_R = 20;
    g.pushMatrix();
    g.translate(0,0,4*SCALE_Z+HEAD_R);
    g.fill(255,255,0);
    g.sphere(HEAD_R);
    g.popMatrix();
    g.popMatrix();
  }
  void takeInputs(KeyHandler keyHandler){
    float r = coor[3];
    accelerating = false;
    for(int i = 0; i < keyHandler.keysDown.length; i++){
      if(keyHandler.keysDown[i]){
        accelerating = true;
      }
    }
    if(keyHandler.keysDown[3]){
      velo[0] -= cos(r)*ACCEL;
      velo[1] -= sin(r)*ACCEL;
    }
    if(keyHandler.keysDown[1]){
      velo[0] += cos(r)*ACCEL;
      velo[1] += sin(r)*ACCEL;
    }
    if(keyHandler.keysDown[2]){
      velo[0] -= sin(r)*ACCEL;
      velo[1] += cos(r)*ACCEL;
    }
    if(keyHandler.keysDown[0]){
      velo[0] += sin(r)*ACCEL;
      velo[1] -= cos(r)*ACCEL;
    }
    if(keyHandler.keysDown[4] && coor[2] <= 0){
      sfx[8].play();
      velo[2] = 12;
    }
  }
  void doPhysics(Room room){
    float[][] kioskWalls = {{320,320},{320,480},{640,480},{640,320},{320,320}};
    for(int d = 0; d < DIM_COUNT+1; d++){
      float[] coor_prev = deepCopy(coor);
      coor[d] += velo[d];
      if(!keyHandler.keysDown[5]){
        checkWallCross(d, room.walls, coor_prev);
        checkWallCross(d, kioskWalls, coor_prev);
      }
      if(d != 2){
        velo[d] *= FRICTION;
      }
    }
    if(coor[2] <= 0 && velo[2] < 0){
      coor[2] = 0;
      velo[2] = 0;
    }else{
      velo[2] -= 1; // gravity
    }
  }
  void lag(float[] arr, float[] dest, float amt){
    for(int i = 0; i < arr.length; i++){
      arr[i] += (dest[i]-arr[i])*amt;
    }
  }
  void checkWallCross(int d, float[][] walls, float[] coor_prev){
    for(int w = 0; w < walls.length; w++){
      int w1 = w;
      int w2 = (w+1)%walls.length;
      float wx1 = walls[w1][0];
      float wx2 = walls[w2][0];
      float wy1 = walls[w1][1];
      float wy2 = walls[w2][1];
      if(wx1 == wx2 && d == 0){ // is vertical
        for(int sign = -1; sign <= 1; sign += 2){
          if(velo[0]*sign > 0 && (coor[1] >= wy1) != (coor[1] >= wy2) &&
          (coor_prev[0]+THICKNESS*sign >= wx1) != (coor[0]+THICKNESS*sign >= wx1)){ // wall crossed
            coor[0] = wx1-(THICKNESS+EPS)*sign;
            velo[0] = -sign*abs(velo[0]);
          }
        }
      }else if(wy1 == wy2 && d == 1){
        for(int sign = -1; sign <= 1; sign += 2){
          if(velo[1]*sign > 0 && (coor[0] >= wx1) != (coor[0] >= wx2) &&
          (coor_prev[1]+THICKNESS*sign >= wy1) != (coor[1]+THICKNESS*sign >= wy1)){ // wall crossed
            coor[1] = wy1-(THICKNESS+EPS)*sign;
            velo[1] = -sign*abs(velo[1]);
          }
        }
      }
    }
  }
  void snapCamera(){
    coor[3] = camera[0];
    lag(lag_coor,coor,0.13);
    lag_coor[3] = coor[3];
    float DISTANCE_FROM_PLAYER = 800;
    float HEIGHT_ABOVE_PLAYER = 100;
    g.translate(0,0,DISTANCE_FROM_PLAYER);
    g.rotateX(PI*0.46-camera[1]);
    g.rotateZ(-lag_coor[3]-PI/2);
    g.translate(-lag_coor[0],-lag_coor[1],-HEIGHT_ABOVE_PLAYER);
  }
}
