import applet.GuiSketch;
import applet.HotswapGuiSketch;
import processing.core.PGraphics;
import processing.core.PVector;
import processing.event.MouseEvent;
import processing.opengl.PShader;


public class Mandelbrot extends HotswapGuiSketch {

    private PShader mandelbrot;
    private PVector cameraPos;
    private float scale = 1;
    private float scaleTarget = 1;
    float t;
    private float recEnd;
    private float recLength;
    private PGraphics canvas;
    String mandelbrotPath = "mandelbrot.glsl";

    public static void main(String[] args) {
        GuiSketch.main("Mandelbrot");
    }

    public void settings() {
        fullScreen(P2D, 2);
//        size(800, 800, P2D);
    }

    public void setup() {
        canvas = createGraphics(width * 2, height * 2, P2D);
        cameraPos = new PVector();
    }

    public void draw() {
        int timeMultiplier = floor(slider("time mult", 1, 5));
        t += radians(1f/timeMultiplier);
        recLength = 360*timeMultiplier;

        uniform(mandelbrotPath).set("t", t);
        uniform(mandelbrotPath).set("scale", scale);
        uniform(mandelbrotPath).set("offset", cameraPos.x, cameraPos.y);
        uniform(mandelbrotPath).set("hueStart", slider("hueStart", 0, 5, .6f));
        uniform(mandelbrotPath).set("hueRange", slider("hueRange", 0, 5, .1f));
        uniform(mandelbrotPath).set("distortMag", slider("distort", 0, .1f, 0));
        if(toggle("time")){
            uniform(mandelbrotPath).set("iter", map(2*abs(recLength/2-(frameCount%recLength)), 0, recLength, 0, slider("maxIter", 1000)));
        }else{
            uniform(mandelbrotPath).set("iter", slider("iter", 1000));
        }
        uniform(mandelbrotPath).set("brLimit", slider("brLimit", 0, 2, 0.2f));
        if (mousePressed) {
            cameraPos.x += (pmouseX - mouseX) * scale * (width / (float) height); //assuming width > height
            cameraPos.y -= (pmouseY - mouseY) * scale;
        }
        scale = lerp(scale, scaleTarget, .2f);

        canvas.beginDraw();
        hotFilter(mandelbrotPath, canvas);
        canvas.endDraw();
        image(canvas, 0, 0, width, height);

        if (recEnd > frameCount) {
            saveFrame(captureDir + "####.jpg");
        }

        gui();
    }

    public void keyPressed() {
        recEnd = frameCount + recLength;
    }

    public void mouseWheel(MouseEvent event) {
        float e = event.getCount();
        if (e < 0) {
            scaleTarget *= .9;
        } else {
            scaleTarget *= 1.1;
        }
    }
}
