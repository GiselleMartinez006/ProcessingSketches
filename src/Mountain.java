import applet.GuiSketch;
import applet.ShadowGuiSketch;
import peasy.PeasyCam;
import processing.core.PGraphics;
import processing.core.PVector;

import java.util.ArrayList;

// Do not rename or move class Mountain
// for it has been shared online
// and people would not find it
public class Mountain extends ShadowGuiSketch {
    private float t;
    private PeasyCam cam;
    private ArrayList<Star> stars = new ArrayList<Star>();
    private float baseWidth;
    private float baseDepth;
    private float maxAltitude;
    private float sunDist;
    private float detail = 60;
    private float[][] fbmGrid = new float[floor(detail)][floor(detail)];
    private float[][] noiseGrid = new float[floor(detail)][floor(detail)];
    private int dayColor = color(85, 97, 150);
    private int nightColor = color(0);
    private float tRecStart = -1;
    private float tRecFinish = -1;
    private float freq = 0;
    private float amp = 0;
    private float freqMod = 0;
    private float ampMod = 0;
    private float nightBlackout;
    private float rockFrq;

    public static void main(String[] args) {
        GuiSketch.main("Mountain");
    }

    public void keyPressed() {
        tRecStart = frameCount;
        tRecFinish = frameCount + 360 * 2;
    }

    public void settings() {
        size(800, 800, P3D);
    }

    public void setup() {
        super.setup();
        cam = new PeasyCam(this, 150);
        baseWidth = 200;
        baseDepth = 200;
        maxAltitude = 100;
        sunDist = maxAltitude * 1.2f;
    }

    public void draw() {
        t = HALF_PI + radians(frameCount * .5f);

        if (button("reset gui")) {
            resetGui();
        }
        if (button("reset seed")) {
            resetFbmGrid();
            resetNoiseGrid();
            noiseSeed(millis());
        }
        updateSlidersAndInvalidateCache();

        translate(0, maxAltitude * .5f);
        super.draw();
        stars();

        if (tRecStart > 0 && frameCount <= tRecFinish) {
            saveFrame(captureFilename);
        }

        noLights();
        gui();

        noStroke();
        fill(255);
        rect(0, 0, 50 * nightBlackout, 5);
    }

    private void updateSlidersAndInvalidateCache() {
        float oldDetail = detail;
        detail = slider("detail", 300);
        if (detail != oldDetail) {
            resetFbmGrid();
        }

        float oldRockFrq = rockFrq;
        rockFrq = slider("rock frq", 0, 1, .1f);
        if (oldRockFrq != rockFrq) {
            resetNoiseGrid();
        }

        float oldFreq = freq;
        float oldAmp = amp;
        float oldFreqMod = freqMod;
        float oldAmpMod = ampMod;
        freq = slider("freq", 0, .3f, .05f);
        amp = slider("amp", 0, 1, .4f);
        freqMod = slider("frq mod", 0, 5, 1.4f);
        ampMod = slider("amp mod", .5f);
        if (oldFreq != freq || oldAmp != amp || oldFreqMod != freqMod || oldAmpMod != ampMod) {
            resetFbmGrid();
        }
    }

    public void setLightDir() {
        lightDir.set(sunDist * sin(t), maxAltitude * .25f * cos(t), -sunDist * cos(t));
    }

    public void background() {
        background(lerpColor(dayColor, nightColor, .5f + .5f * cos(t)));
    }

    public void animate(PGraphics canvas) {
        float logicalCenter = (detail - 1) / 2f;
        float maxDistFromLogicalCenter = detail * .5f;
        nightBlackout = constrain(1 - cos(t), 0, 1);
        canvas.pushMatrix();
        canvas.noStroke();
        canvas.fill(0);
        for (int zIndex = 0; zIndex < detail; zIndex++) {
            canvas.beginShape(TRIANGLE_STRIP);
            for (int xIndex = 0; xIndex < detail; xIndex++) {
                float x = map(xIndex, 0, detail - 1, -baseWidth * .5f, baseWidth * .5f);
                float z0 = map(zIndex, 0, detail - 1, -baseDepth * .5f, baseDepth * .5f);
                float z1 = map(zIndex + 1, 0, detail - 1, -baseDepth * .5f, baseDepth * .5f);
                float d0 = 1 - constrain(map((dist(xIndex, zIndex, logicalCenter, logicalCenter)), 0, maxDistFromLogicalCenter, 0, 1), 0, 1);
                float d1 = 1 - constrain(map((dist(xIndex, zIndex + 1, logicalCenter, logicalCenter)), 0, maxDistFromLogicalCenter, 0, 1), 0, 1);
                float n0 = getFbmAt(xIndex, zIndex);
                float n1 = getFbmAt(xIndex, zIndex + 1);
                float y0 = -d0 * maxAltitude + maxAltitude * n0;
                float y1 = -d1 * maxAltitude + maxAltitude * n1;

                float rock0 = 150 * getNoiseAt(xIndex, zIndex);
                float gray0 = nightBlackout * (isSnow(y0, n0) ? 255 : rock0);
                canvas.fill(gray0);
                canvas.normal(x, y0, z0);
                canvas.vertex(x, y0, z0);

                float rock1 = 150 * getNoiseAt(xIndex, zIndex + 1);
                float gray1 = nightBlackout * (isSnow(y1, n1) ? 255 : rock1);
                canvas.fill(gray1);
                canvas.normal(x, y1, z1);
                canvas.vertex(x, y1, z1);
            }
            canvas.endShape(TRIANGLE_STRIP);
        }
        canvas.popMatrix();
    }

    private boolean isSnow(float y, float n) {
        return y < -maxAltitude / 2 + 2.5f * maxAltitude * n;
    }

    private void resetNoiseGrid() {
        noiseGrid = new float[ceil(detail)][ceil(detail)];
        for (int i = 0; i < detail; i++) {
            for (int j = 0; j < detail; j++) {
                noiseGrid[i][j] = -1;
            }
        }
    }

    private float getNoiseAt(int x, int y) {
        if (x < 0 || x >= noiseGrid.length || y < 0 || y >= noiseGrid.length) {
            return 0;
        }
        float val = noiseGrid[x][y];
        if (val == -1) {
            val = noise(x * rockFrq, y * rockFrq);
            noiseGrid[x][y] = val;
        }
        return val;
    }

    private void resetFbmGrid() {
        fbmGrid = new float[ceil(detail)][ceil(detail)];
        for (int i = 0; i < detail; i++) {
            for (int j = 0; j < detail; j++) {
                fbmGrid[i][j] = -1;
            }
        }
    }

    private float getFbmAt(int x, int y) {
        if (x < 0 || x >= fbmGrid.length || y < 0 || y >= fbmGrid.length) {
            return 0;
        }
        float val = fbmGrid[x][y];
        if (val == -1) {
            val = fbm(x, y);
            fbmGrid[x][y] = val;
        }
        return val;
    }

    private float fbm(float x, float y) {
        float sum = 0;
        float amp = this.amp;
        float freq = this.freq;
        for (int i = 0; i < 6; i++) {
            sum += amp * (-1 + 2 * noise(x * freq, y * freq));
            freq *= freqMod;
            amp *= ampMod;
            x += 50;
            y += 50;
        }
        return abs(sum);
    }

    private void stars() {
        if (stars.isEmpty()) {
            for (int i = 0; i < 1000; i++) {
                stars.add(new Star());
            }
        }
        pushMatrix();
        rotateY(-t);
        for (Star s : stars) {
            s.update();
        }
        popMatrix();
    }

    class Star {
        PVector pos = PVector.random3D().setMag(maxAltitude * 2);
        float weight = random(1, 3);

        void update() {
            strokeWeight(weight);
            stroke(255, 255 * (.3f + .7f * cos(t)));
            noFill();
            point(pos.x, pos.y, pos.z);
        }
    }
}
