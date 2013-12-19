//
//  ViewController.m
//  ES3 Framebuffer Fetch
//
//  Created by Volker Schönefeld on 18/12/13.
//  Copyright (c) 2013 Limbic. All rights reserved.
//
#import "ViewController.h"
#include <numeric>
#include <list>
#include <vector>
#include <mach/mach_time.h>
#include "lamb/render/glprogram.h"
#include "lamb/math/camera.h"
#include "lamb/render/vbomodel.h"

static mach_timebase_info_data_t timebase;
double Time() {
  uint64_t t = mach_absolute_time();
  if ( timebase.denom == 0 ) {
    mach_timebase_info(&timebase);
  }
  return ((double)t * 1e-9 * (double)timebase.numer / (double)timebase.denom );
}

NSString *StringFromFile(const char *const name, const char *const ext) {
  NSString *file = [[NSBundle mainBundle] pathForResource:@(name)
                                                   ofType:@(ext)];
  return [NSString stringWithContentsOfFile:file
                                   encoding:NSUTF8StringEncoding
                                      error:nil];
}

float frand() {
  return float(random()) / float(RAND_MAX);
}

struct Quad {
  float x, y;
  float w, h;
  float vx, vy;
  float r, g, b, a;
};

@interface ViewController () {
  IBOutlet UILabel *timer_;
  IBOutlet UILabel *info_;
  IBOutlet UILabel *tris_;
  IBOutlet UILabel *tris_per_sec_;
  IBOutlet UISlider *complexity_;
  IBOutlet UISegmentedControl *technique_;
  GLProgram *es2_program_;
  VBOModel *rect_;
  int es2_uni_mvp_;
  int es2_uni_color_;
  std::list<double> frame_times_;
  std::list<double> pixels_drawn_;
  int num_objects_last_draw_;
  int num_pixels_drawn_;
  double last_time_;
  double last_update_time_;
  std::list<Quad> quads_;
}
@property (strong, nonatomic) EAGLContext *context;

- (void)setupGL;
- (void)tearDownGL;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
    self.preferredFramesPerSecond = 60;
    
    [self setupGL];
}

- (void)dealloc
{    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  if ([self isViewLoaded] && ([[self view] window] == nil)) {
    self.view = nil;
    [self tearDownGL];
    if ([EAGLContext currentContext] == self.context) {
      [EAGLContext setCurrentContext:nil];
    }
    self.context = nil;
  }
  // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}

- (void)setupGL {
  [EAGLContext setCurrentContext:self.context];
  // Load shaders
  es2_program_ = GLProgram::FromText(StringFromFile("es2", "vsh").UTF8String, StringFromFile("es2", "fsh").UTF8String);
  es2_program_->Link();
  es2_uni_mvp_ = es2_program_->GetUniformLocation("uni_mvp");
  es2_uni_color_ = es2_program_->GetUniformLocation("uni_color");
  rect_ = VBOModel::Load("rect");
}

- (void)tearDownGL {
  [EAGLContext setCurrentContext:self.context];
  SAFE_DELETE(es2_program_);
  SAFE_DELETE(rect_);
}

#pragma mark - GLKView and GLKViewController delegate methods

const int kMinComplexity = 10;
const int kMaxComplexity = 1000;

- (void)update {
  // Compute animation
  double now = Time();
  double delta = now - last_update_time_;
  if (last_update_time_ == 0) {
    delta = 0.0;
  }
  last_update_time_ = now;
  float fdelta = float(delta);
  // Update
  int complexity = int(lerp(kMinComplexity, complexity_.value, kMaxComplexity));
  // Remove quads that are too many
  while (quads_.size() > complexity) {
    quads_.pop_back();
  }
  // Now add more quads if required
  for (size_t i = quads_.size(); i < complexity; ++i) {
    float x = frand() * 2 - 1;
    float y = frand() * 2 - 1;
    float w = frand() * 0.9f + 0.1f;
    float h = frand() * 0.9f + 0.1f;
    float vx = frand() * 2 - 1;
    float vy = frand() * 2 - 1;
    float r = frand();
    float g = frand();
    float b = frand();
    float a = frand() * 0.5f + 0.25f;
    quads_.push_back(Quad{x, y, w, h, vx, vy, r, g, b, a});
  }
  // Finally update all quads
  auto qit = quads_.begin();
  while (qit != quads_.end()) {
    Quad & q = *qit++;
    q.x += q.vx * fdelta;
    q.y += q.vy * fdelta;
    // flip the velocities if the quad leaves the screen
    if (q.x - q.w/2 < -1.0f && q.vx < 0.0f) {
      q.vx = -q.vx;
    }
    if (q.x + q.w/2 > 1.0f && q.vx > 0.0f) {
      q.vx = -q.vx;
    }
    if (q.y - q.h/2 < -1.0f && q.vy < 0.0f) {
      q.vy = -q.vy;
    }
    if (q.y + q.h/2 > 1.0f && q.vy > 0.0f) {
      q.vy = -q.vy;
    }
  }
}

- (void)drawScene {
  GLKView *view = (GLKView*)self.view;
  int w = int(view.drawableWidth);
  int h = int(view.drawableHeight);
  int tech = int(technique_.selectedSegmentIndex);
  glDisable(GL_DEPTH_TEST);
  num_pixels_drawn_ = 0;
  if (tech == 0) {
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    es2_program_->Use();
    auto qit = quads_.begin();
    while (qit != quads_.end()) {
      Quad & q = *qit++;
      Transform t;
      t.glTranslate(q.x, q.y, 0.0f);
      t.glScale(q.w, q.h, 1.0f);
      glUniformMatrix4fv(es2_uni_mvp_, 1, 0, t.raw());
      glUniform4f(es2_uni_color_, q.r, q.g, q.b, q.a);
      rect_->Draw();
      // Compute area
      num_pixels_drawn_ += q.w/2.0f * w * q.h/2.0f * h;
    }
    glDisable(GL_BLEND);
  }
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
//  float w = view.bounds.size.width;
//  float h = view.bounds.size.height;
  glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);
  [self drawScene];
  // Update frame timer
  double now = Time();
  double diff = now - last_time_;
  last_time_ = now;
  frame_times_.push_back(diff);
  pixels_drawn_.push_back(num_pixels_drawn_);
  if (frame_times_.size() >= 10) {
    double avg_diff = std::accumulate(frame_times_.begin(), frame_times_.end(), 0.0) / double(frame_times_.size());
    double ms = avg_diff * 1000.0;
    double avg_numpix = std::accumulate(pixels_drawn_.begin(), pixels_drawn_.end(), 0.0) / double(pixels_drawn_.size());
    frame_times_.clear();
    pixels_drawn_.clear();
    timer_.text = [NSString stringWithFormat:@"%.1f ms/frame", ms];
    info_.text = [NSString stringWithFormat:@"%zu quads", quads_.size()];
    tris_.text = [NSString stringWithFormat:@"%.1fm pixels", num_pixels_drawn_/1000000.0f];
    tris_per_sec_.text = [NSString stringWithFormat:@"%.1fm pixels/sec", float(avg_numpix/avg_diff/1000000)];
  }
}

- (IBAction)change:(id)sender {
  frame_times_.clear();
  pixels_drawn_.clear();
  num_pixels_drawn_ = 0;
}

@end
