import java.util.*;
import java.lang.Math.*;

//========== Point Class =================

class Point {
 private float X = 0;
 private float Y = 0;
 
 Point (float X, float Y) {
   this.X = X;
   this.Y = Y;
 }
 
 // getters
 public float GetX () {
   return this.X;
 }
 
 public float GetY () {
   return this.Y;
 }
 
 // setters
 public void SetX (float value) {
   this.X = value; 
 }
 
 public void SetY (float value) {
   this.Y = value; 
 }

 // methods
 public boolean isEqual ( Point p ) {
   if ( abs( this.X - p.GetX() ) < 0.2 && abs( this.Y - p.GetY() ) < 0.2 )
   { return true; }

   return  false;
 }

 @Override
 public boolean equals ( Object o ) {
    if (o == this) 
    {
      return true;
    }
 
    if (!(o instanceof Point)) 
    {
      return false;
    }
         
    Point p = (Point) o;
         
    return this.isEqual( p );
 }
}

//========== Global variables =================

int pointSize = 10;                                     // size of all points being drawn

ArrayList<Point> points = new ArrayList<Point>();       // ArrayList of all existing points in window
ArrayList<Point> hullConvex = new ArrayList<Point>();   // arraylist of points belonging to convex hull

boolean hoverPoint = false;                             // mouse cursor over a point = true
boolean heldPoint = false;                              // left mouse click on a point = true

float xOffset = 0;                                      // offset on X axis of a dragged point
float yOffset = 0;                                      // offset on Y axis of a dragged point

boolean editMode = false;                               // edit mode is on = true
Point clickedPoint = new Point(0,0);                    // clicked on point used for dragging

//========== Setup =================

void setup () {
  size(1280,960);
  background(0);
  frameRate(60);
  noStroke();
}

//========== Sweep line triangulation =================

// draw a line between 2 points
void drawLine ( Point a, Point b ) {
  line(a.GetX(), a.GetY(), b.GetX(), b.GetY() );
}

// draw triangulated polygon
void drawPolygon () {
  
  for ( int i = 1; i < points.size(); ++i )
  {
    stroke(255);
    line(points.get(i-1).GetX(), points.get(i-1).GetY(), points.get(i).GetX(), points.get(i).GetY());
  }
  // line between the last and the first element of the polygon
  //line(points.get(points.size()-1).GetX(), points.get(points.size()-1).GetY(), points.get(0).GetX(), points.get(0).GetY());
  drawLine( points.get(points.size()-1), points.get(0) );
}

void sweepLineTriang () {

  // draw polygon created by the user
  drawPolygon();

  // check if there are enough points to create a polygon
  if ( points.size() < 4 ) return;

  // find the extreme points on y-axis as top and bot
  Point top, bot;
  int topIndex, botIndex;                   // indexes of top and bot in terms of their position in list points

  top = bot = points.get(0);
  topIndex = botIndex = 0;

  for ( int i = 1; i < points.size(); ++i )
  {
    if ( points.get(i).GetY() > top.GetY() )
    {
      top = points.get(i);
      topIndex = i;
    }
    else if ( points.get(i).GetY() < bot.GetY() ) 
    {
      bot = points.get(i);
      botIndex = i; 
    }
  }

  // create left and right side lists based on extreme points top and bot
  // it is possible to technically have the right side inside leftSide, but it shouldn't matter
  ArrayList<Point> leftSide = new ArrayList<Point>();
  ArrayList<Point> rightSide = new ArrayList<Point>();

  for ( int j = topIndex; !points.get(j).isEqual( points.get(botIndex) ); )
  {                                                                                                                               
    leftSide.add( points.get(j) );
    j = Math.floorMod( j + 1, points.size() );
  }

  for ( int j = topIndex; !points.get( Math.floorMod(j, points.size()) ).isEqual( points.get(botIndex) ); )
  {
    rightSide.add( points.get(j) );
    j = Math.floorMod( j - 1, points.size() );
  }

  // sort lexicographically vertices in points
  Collections.sort( points, (p1, p2) -> 
                                        {
                                          if ( p1.GetY() == p2.GetY() ) return (int)(p1.GetX() - p2.GetX() + 0.5);
                                          else return (int)(p1.GetY() - p2.GetY() + 0.5);
                                        } );

  // first two vertices pushed into stack
  Stack<Point> stack = new Stack<Point>();
  stack.push(points.get(0));
  stack.push(points.get(1));

  // triangulation itself
  for ( int k = 2; k < points.size(); ++k )
  {
    Point eventPoint = points.get(k);

    if ( ( leftSide.contains( stack.peek() ) && leftSide.contains( eventPoint ) ) || ( rightSide.contains( stack.peek() ) && rightSide.contains( eventPoint ) )  )
    {
      Point popped;                 // last point popped from the stack

      // pop top of stack, because it can't create a triangle with eventPoint
      popped = stack.pop();       // if while loop doesn't create any triangle -> push this point back on stack

      // loop as along as we can create triangles
      while ( !stack.isEmpty() && angleThreePoints( stack.peek(), popped, eventPoint ) > 0 )
      {
        popped = stack.pop();
        drawLine( popped, eventPoint );
      }
      
      stack.push( popped );
      stack.push( eventPoint );
    }
    else        // points are on the opposite sides of the polygon
    {
      Point topStack = stack.pop();
      drawLine( eventPoint, topStack );

      while ( !stack.empty() )
      {
        drawLine( stack.pop(), eventPoint );
      }

      stack.push( topStack );
      stack.push( eventPoint );  
    }
  }

}

//========== Graham Hull =================

Point findRightmost () {

  Iterator<Point> iter = points.iterator();

  Point pivot = iter.next();
  Point temp = new Point(0,0);

  // find and return the pivot as an extreme on the x axis
  while ( iter.hasNext() )
  {
    temp = iter.next();

    if ( temp.GetX() > pivot.GetX() )
      pivot = temp;
  }

  return pivot;
}

// custom compare function for sort comparator in hullGraham()
int compareByAngle ( Point pivot, Point q, Point lhs, Point rhs ) {

    double angleLhs, angleRhs;
    Point leadVector = new Point ( q.GetX()-pivot.GetX(), q.GetY()-pivot.GetY() );

    // angle between pivot, q, lhs
    if ( pivot.isEqual(lhs) ) angleLhs = 0.0;
    else angleLhs = angleTwoVectors ( leadVector, new Point (lhs.GetX()-pivot.GetX(), lhs.GetY()-pivot.GetY()) );

    // angle between pivot, q, rhs
    if ( pivot.isEqual(rhs) ) angleRhs = 0.0;
    else angleRhs = angleTwoVectors ( leadVector, new Point (rhs.GetX()-pivot.GetX(), rhs.GetY()-pivot.GetY()) );

    // return -1 = lhs < rhs; 0 = lhs == rhs; 1 = lhs > rhs
    if ( angleLhs == angleRhs ) return 0;
    else 
    {
      return (angleLhs > angleRhs) ? 1 : -1;
    }
}

// p = center point, q = existing point, r = new point to add - cross product
// return <0 -> angle > 180° , return >0 -> angle < 180°
float angleThreePoints (Point p, Point q, Point r) {

  // r = the last point added to the potential convex hull
  return ( ( (p.GetX() - r.GetX()) * (q.GetY() - p.GetY()) ) - ( (p.GetY() - r.GetY()) * (q.GetX() - p.GetX()) ) );
}

void hullGraham () {

  // delete the hull
  deletehullConvexWrap();

  // check if we have enough points to construct a convex hull
  if ( points.size() < 3 ) return;

  Stack<Point> stack = new Stack<Point>();
  Point pivot = findRightmost();
  Point q = new Point( pivot.GetX(), 0.0 );         // separating line from pivot

  stack.push(pivot);                                // add pivot to the convex hull

  // sort all the points based on angle from pivot
  Comparator<Point> comparator = (r, s) -> compareByAngle( pivot, q, r, s);
  points.sort( comparator );

  // add point with biggest angle from pivot to the convex hull
  stack.push(points.get(1));                        

  //==== testing of sort ====
  /*for ( int i = 0; i < points.size(); ++i )
  {
    System.out.println( i + ". bod je x: " + points.get(i).GetX() + " a y: " + points.get(i).GetY() );
  }
  System.out.println("Pivot je x: " + pivot.GetX() + " a y: " + pivot.GetY());*/

  // execute the alhorithm itself
  for ( int j = 2; j < points.size(); )
  {
      Point stackTop = stack.pop();
      Point stackBot = stack.peek();
    
    if ( angleThreePoints( stackTop, stackBot, points.get(j) ) > 0.0 )
    {
      // left turn
      stack.push( stackTop );
      stack.push( points.get(j) );
      ++j;
    }

    // else - top of stack is already popped -> do nothing
  }

  // pop all points from stack and add them to hullConvex to create the hull
  while ( !stack.empty() )
  {
    hullConvex.add( stack.pop() );
  }
}

//========== Gift wrap Hull =================

// p and q are actually used as vectors to compute the angle in between them
double angleTwoVectors ( Point p, Point q ) {

  // return value in an interval <0.0 ; PI>
  return Math.acos( ( p.GetX() * q.GetX() + p.GetY() * q.GetY() ) / 
                    ( sqrt( p.GetX()*p.GetX() + p.GetY()*p.GetY() ) * sqrt( q.GetX()*q.GetX() + q.GetY()*q.GetY() ) ) );
}

void deletehullConvexWrap () {

  hullConvex.removeAll(hullConvex);
  background(0);
}

void createHullGiftWrap (Point pivot, Point q) {

  // compute the angle between pivot and all other remaining points
  int nextPointIdx = 0;
  double maxAngle = 0.0;
  for ( int i = 0; i < points.size(); ++i)
  {
    double angle = angleTwoVectors( new Point(q.GetX()-pivot.GetX(), q.GetY()-pivot.GetY()), new Point(points.get(i).GetX()-pivot.GetX(), points.get(i).GetY()-pivot.GetY()) );
    if ( Math.abs(angle) > Math.abs(maxAngle) )
    {
      nextPointIdx = i;
      maxAngle = angle;
    }
  }

  // is the point we are trying to add the original pivot?
  if ( !hullConvex.get(0).isEqual( points.get(nextPointIdx) ) )
  {
    hullConvex.add(points.get(nextPointIdx));
    q = pivot;
    pivot = points.get(nextPointIdx);
    createHullGiftWrap(pivot, q);
  }
  else
  {
    return;
  }
}

void hullGiftWrap () {

  // clear array list to begin anew
  deletehullConvexWrap();

  // check if we have enough points to construct a convex hull
  if ( points.size() < 3 ) return;
  
  Point pivot = findRightmost();
  hullConvex.add(pivot);
  
  Point q = new Point(pivot.GetX(), 0);

  createHullGiftWrap(pivot, q);
  
  // drawing of the convex hull in draw()
}

//========== Basic interatctions =============

void wipeWindow () {
  background(0); 
  points.removeAll(points);
  deletehullConvexWrap();
}

void deletePointAt (float x_coord, float y_coord) {
  Iterator<Point> iter = points.iterator();
  Point temp = new Point(0,0);

  // loop through list of existing points
  while ( iter.hasNext() )
  {
   temp = iter.next();

   // if one matches the coordinates
   if ( ( abs(temp.GetX() - x_coord) <= 5 ) && ( abs(temp.GetY() - y_coord) <= 5 ) )
   {
     // delete it
     fill(0);
     circle(temp.GetX(), temp.GetY(), pointSize+2);
     iter.remove();
     break;
   }
  }

  fill(255);
}

void drawPointAt (float x_coord, float y_coord) {

  deletePointAt( x_coord, y_coord );
  points.add(new Point(x_coord, y_coord));
  System.out.println("Point created at X:" + x_coord + " and Y:" + y_coord);
}

void drawPointAt ( Point p ) {

  deletePointAt( p.GetX(), p.GetY() );
  points.add(p);
  System.out.println("Point created at X:" + p.GetX() + " and Y:" + p.GetY());
}

// create 5 random points
void randomPoints () {
  float x_coord = 0;
  float y_coord = 0;
  
  for ( int i = 0; i < 5; i++ ) 
  {
    x_coord = (float)(Math.random() * width + 1);
    y_coord = (float)(Math.random() * height + 1);
    drawPointAt(x_coord, y_coord);
  }  
}

//========== Mouse interaction =================

boolean checkHover () {
  Iterator<Point> iter = points.iterator();
  Point temp = new Point(0,0);
  
  // check for a point at the coordinates of hovering mouse
  while ( iter.hasNext() )
  {
   temp = iter.next();

   if ( ( abs(temp.GetX() - mouseX) <= 5 ) && ( abs(temp.GetY() - mouseY) <= 5 ) )
   {
     fill(0);
     circle(temp.GetX(), temp.GetY(), pointSize+2);                     // delete the point over which the cursor is hovering
     
     iter.remove();                                                    
     clickedPoint = temp;

     return true;
   }
  }
  
  return false;
}

void mouseDragged () {

  if ( editMode && heldPoint )
  {
      clickedPoint.SetX(mouseX - xOffset);                    
      clickedPoint.SetY(mouseY - yOffset);
  }
}
 
void mousePressed () {
  
  if ( !editMode && mouseButton == LEFT ) 
  {
    drawPointAt(mouseX, mouseY);
  }
  else if ( !editMode && mouseButton == RIGHT )
  {
    deletePointAt(mouseX, mouseY);
  }
  else if ( editMode && checkHover() )
  {
    heldPoint = true;                                           
  }
  
  xOffset = mouseX - clickedPoint.GetX();                  
  yOffset = mouseY - clickedPoint.GetY();
}

void mouseReleased () {

  if ( editMode && heldPoint )
  {
    drawPointAt(clickedPoint);

    editMode = false;
    heldPoint = false;
  }  
}

//========== Keyboard interaction ==============

void keyReleased() {

  if ( key == 'r' || key == 'R' )
  {
    editMode = false;
    randomPoints();
  }
  else if ( key == 'c' || key == 'C' ) 
  {
    editMode = false;
    wipeWindow();
  }
  else if ( key == 'h' || key == 'H' )
  {
    editMode = false;
    hullGiftWrap();
  }
  else if ( key == 'e' || key == 'E' ) 
  {
    editMode = true;
    deletehullConvexWrap();
  }   
  else if ( key == 'g' || key == 'G' ) 
  {
    editMode = false;
    System.out.println("Trying to create Graham Scan convex hull.");
    hullGraham();
  }
  else if ( key == 's' || key == 'S' )
  {
    editMode = false;
    sweepLineTriang();
  }   
}

//========== Draw loop =================

void draw () {    
  textSize(14);
  text("LMB - draw a point\n"
     + "RMB - delete a point\n"
     + "r - draw random points\n"
     + "c - delete all points\n"
     + "e - edit points' positions\n"
     + "h - create convex hull (gift wrap)\n"
     + "g - create convex hull (Graham)\n"
     + "s - sweep line triangulation"
     , 10, 30); 

  // draw all existing points
  fill(255);
  Iterator<Point> it = points.iterator();

  while ( it.hasNext() )
  {
    Point temp = it.next();
    circle(temp.GetX(), temp.GetY(), pointSize);
  }
  
  // draw a convex hull
  if ( !hullConvex.isEmpty() )
  {  
    for ( int i = 1; i < hullConvex.size(); ++i )
    {
      stroke(255);
      line(hullConvex.get(i-1).GetX(), hullConvex.get(i-1).GetY(), hullConvex.get(i).GetX(), hullConvex.get(i).GetY());
    } 
    // line between the last and the first element of the convex hull
    line(hullConvex.get(hullConvex.size()-1).GetX(), hullConvex.get(hullConvex.size()-1).GetY(), hullConvex.get(0).GetX(), hullConvex.get(0).GetY());
  }
}
