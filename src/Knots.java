import applet.HotswapGuiSketch;

public class Knots extends HotswapGuiSketch {
    public static void main(String[] args) {
        HotswapGuiSketch.main("Knots");
    }

    float t = 0;

    public void settings() {
        size(800, 800, P3D);
    }

    public void setup(){

    }

    public void draw(){
        if(toggle("dark",true)){
            background(0);
            stroke(255);
        }else{
            background(255);
            stroke(0);
        }
        if(button("reset")){
            resetGui();
        }
        noFill();
        translate(width*.5f,height*.5f);
        t += slider("rotation",-.1f,.1f);
        strokeWeight(slider("weight",0,10,2));
        for(int i = 1; i <= slider("knots",0,24); i++){
            beginShape();
            for(int j = 0; j < slider("detail",100); j++){
                float jN = map(j,0,slider("detail")-1,0,1);
                float a = jN*slider("a max",0,TWO_PI,TWO_PI);
                float r = slider("radius",0,500,150)
                        +slider("amp",0,200,30)
                        *sin(floor(slider("freq",0,12,3))*a);
                a += t+map(i,1,floor(slider("knots")),0,TWO_PI);
                vertex(r*cos(a), r*sin(a));
            }
            endShape();
        }
        rgbSplitPass(g);
        rec();
        gui();
    }
}
