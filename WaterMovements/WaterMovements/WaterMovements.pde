import processing.video.*;
import processing.sound.*;   

//Movie video;
SoundFile dropSound;  
SoundFile waterSound;
SoundFile waterEnd;

PImage img;
float[][] rippleMap1, rippleMap2; 
int simCols, simRows; // resolucio de la simulacio
int cols, rows;       // resolucio de la pantalla
int flag;

void setup() {
  fullScreen();
  img = loadImage("Data/Koi2.jpeg");
  img.resize(width, height);
  dropSound = new SoundFile(this, "Data/WaterDrop.mp3");
  waterSound = new SoundFile(this, "Data/WaterMoving.mp3");
  waterEnd = new SoundFile(this, "Data/WaterEnd.mp3");
  cols = width;
  rows = height;

  
  simCols = width / 2;
  simRows = height / 2;

  rippleMap1 = new float[simCols][simRows];
  rippleMap2 = new float[simCols][simRows];
}

void draw() {
  
  loadPixels();
  
  //Utilitzo equacio de propagacio de ones per simular que la gota es propaga per la pantalla
  //Utilitzo una simulacio per que es procesament sigui mes rapid
  for (int x = 1; x < simCols-1; x++) {
    for (int y = 1; y < simRows-1; y++) {
      //equcio de propagacio
      rippleMap2[x][y] = (rippleMap1[x-1][y] + rippleMap1[x+1][y] + rippleMap1[x][y-1] + rippleMap1[x][y+1]) / 2 - rippleMap2[x][y];
      //Multiplico per forquilla de valors menors que 1, perque vagi atenuant el valor fins que acabi la ona
      rippleMap2[x][y] *= random(0.80,0.99);
    }
  }

  //Llegeixo de la simulacio feta i paso la informacio a la imatge original per aplicar el efecte
  for (int x = 0; x < cols; x++) {
    for (int y = 0; y < rows; y++) {
      //Agafo els valors per la simulacio, i amb aixo creo un offset que utilitzare mes tard per aplicar els punts d'energia sobre la imat
      int simX = x / 2;
      int simY = y / 2;

      float offset = rippleMap2[simX][simY];

      int dx = (int)(x + offset);
      int dy = (int)(y + offset);
      dx = constrain(dx, 0, cols-1);
      dy = constrain(dy, 0, rows-1);

      int loc1 = x + y*cols;
      int loc2 = dx + dy*cols;

      pixels[loc1] = img.pixels[loc2];
    }
  }

  updatePixels();
  //Canvio els buffers per tal de que el buffer actualitzat sigui el que utilitza ara
  float[][] temp = rippleMap1;
  rippleMap1 = rippleMap2;
  rippleMap2 = temp;
  }
  
void mousePressed() {
  flag = 1;
  if (mouseButton == LEFT) {
    addDrop(mouseX/2, mouseY/2, random(50, 500)); 
    dropSound.amp(0.3);
    dropSound.play(); 
  }
}

//funcio extra per tal de que si mous el ratoli amb el boto pulsat, tambe es faci el efecte
void mouseDragged() {
  flag = 0;
  if (mouseButton == LEFT) {
    addDrop(mouseX/2, mouseY/2, random(50, 500));
    if (!waterSound.isPlaying()) {
      waterSound.amp(0.1);
      waterSound.loop();
    }
  }
}

void mouseReleased() {
  if(flag == 0) {
    waterEnd.play();
  }
  waterSound.stop(); 
}

//Afegeix la cota al mapa en funcio de la força que li entra
void addDrop(int x, int y, float strength) {
  if (x <= 1 || x >= simCols-1 || y <= 1 || y >= simRows-1) return;
  rippleMap1[x][y] += strength;
}
