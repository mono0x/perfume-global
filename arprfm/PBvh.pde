public class PBvh {
  public BvhParser parser;

  public PBvh(String[] data) {
    parser = new BvhParser();
    parser.init();
    parser.parse( data );
  }

  public void update( int ms ) {
    parser.moveMsTo( ms );//30-sec loop
    parser.update();
  }

  public void draw(int c, int a) {
    for(BvhBone b : parser.getBones()) {
      pushMatrix();
      translate(b.absPos.x, b.absPos.y, b.absPos.z);
      fill(c, a);
      //ellipse(0, 0, 4, 4);
      sphereDetail(6);
      sphere(4);
      noFill();
      popMatrix();
      if(!b.hasChildren()) {
        pushMatrix();
        translate( b.absEndPos.x, b.absEndPos.y, b.absEndPos.z);
        fill(c, a);
        //ellipse(0, 0, 20, 20);
        sphereDetail(12);
        sphere(10);
        noFill();
        popMatrix();
      }
      if(!b.isRoot()) {
        BvhBone parent = b.getParent();
        stroke(c, a);
        line(b.absPos.x, b.absPos.y, b.absPos.z, parent.absPos.x, parent.absPos.y, parent.absPos.z);
        noStroke();
      }
    }
  }
}
