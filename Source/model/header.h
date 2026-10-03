/*
 This file contains all include files, the #defines, structures and globals used in the simulation.
 All the functions are prototyped in this file as well.
*/

// External include files
#include <iostream>
#include <fstream>
#include <sstream>
#include <string.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/stat.h>
#include <signal.h>
#include <unistd.h>
#include <stdbool.h>
#include <vector> //needed for VBOs

// Needed to make 
#include <cuda_runtime.h>

// OpenGL headers - GLAD must come BEFORE GLFW
#include "../include/glad/glad.h"
#include <GL/glu.h>
#include <GLFW/glfw3.h>

// ImGui headers - use quotes for local includes, not angle brackets
#include "../third_party/imgui/imgui.h"
#include "../third_party/imgui/imgui_impl_glfw.h"
#include "../third_party/imgui/imgui_impl_opengl3.h"

using namespace std;

// Cuda defines
#define BLOCKNODES 256
#define BLOCKMUSCLES 256

// Defines for terminal print
#define BOLD_ON  "\e[1m"
#define BOLD_OFF   "\e[m"

// Math defines.
#define PI 3.141592654
#define ASUMEZERO 0.0000001f
#define FLOATMAX 3.4028235e+38f
#define INTMAX 2147483647

// Structure defines. 
// This sets how many muscle can be connected to a node.
#define MUSCLES_PER_NODE 20

// Structures
// Everything a node holds. We have 1 on the CPU and 1 on the GPU
struct nodeAttributesStructure
{
        int type;
	float4 position;
	bool isBeatNode;
	float beatPeriod;
	float beatTimer;
	bool isFiring;
	bool isAblated;
	bool isDrawNode;
	float4 color;
	int muscle[MUSCLES_PER_NODE];
};

// Everything a muscle holds. We have 1 on the CPU and 1 on the GPU
struct muscleAttributesStructure
{
        int type;
	int nodeA;
	int nodeB;    
	int apNode;
	bool isOn;
	bool isEnabled;
	float timer;
	float naturalLength;
	float conductionVelocity;
	float conductionDuration;
	float refractoryPeriod;
	float absoluteRefractoryPeriodFraction;
	float4 color;
};

// This structure will contain all the switches that control the actions in the code.
// 
struct simulationSwitchesStructure
{
	bool isPaused;
	bool isInAblateMode;
	bool isInEctopicBeatMode;
	bool isInEctopicEventMode;
	bool isInAdjustMuscleAreaMode;
	bool isInAdjustMuscleLineMode;
	bool isInFindNodeMode;
	bool isInFindMuscleMode;
	bool isInMouseFunctionMode;
	bool isRecording;
	int ViewFlag; 
	// Draws where the AP signal is along a muscle strand.
	bool isDrawAP;
	// This is a three way toggle. With draw no nodes, draw the front half of the nodes, or draw all nodes.  0 = off, 1 = front half, 2 = all
	int DrawNodesFlag; 
	// Tells the program to draw the front half of the simulation or the full simulation.
	// We put it in because sometimes it is hard to tell if you are looking at the front of the simulation
	// or looking through a hole to the back of the simulation. By turning the back off it allows you to
	// orient yourself.
	int DrawFrontHalfFlag;
	bool ShowMuscleTypesFlag;
	// For Find Nodes functionality
	//These need to be globals or they get wiped when the GUI redraws
	bool nodesFound;       // Whether nodes have been identified
	int frontNodeIndex;    // Index of the frontmost node (max Z)
	int topNodeIndex;      // Index of the topmost node (max Y)
	//GUI related
	bool guiCollapsed; // for hotkey to collapse GUI
};

// Globals Start ******************************************
// Make sure any globals that are not initialived in one of the simulation setup files
// (AdvancedSimulationSetup, IntermediateSimulationSetup, BasicSimulationSetup) are save
// when a simulation is saved in the previuos runs file.

// How many nodes and muscle the simulation contains.
// They are initially read in form files in the NodesMuscles folder.
// *** Should be stored if a runfile is saved.
int NumberOfNodes = -1;
int NumberOfMuscles = -1;

// This will hold all the nodes.
// It is initially read in form files in the NodesMuscles folder.
// *** The Nodes (CPU values) should be stored if a runfile is saved.
nodeAttributesStructure *Node;
nodeAttributesStructure *NodeGPU;

// This will hold all the muscles.
// It is initially read in form files in the NodesMuscles folder.
// *** The Muscles (CPU values) should be stored if a runfile is saved.
muscleAttributesStructure *Muscle;
muscleAttributesStructure *MuscleGPU;

// This will hold all the simulation switches.
// It is initialized in setNodesAndMuscles.h/setRemainingParameters().
// *** Should be stored if a runfile is saved.
simulationSwitchesStructure SimulationSwitch;

// Used for videos and screenshots variables
// CaptureWidth and CaptureHeight they are intially in Main().
// MovieFile and Buffer are opened/allocated in callBackFunctions.h/movieOn()
// and closed/freed in callBackFunctions.h/movieOff().
FILE* MovieFile; // File that holds all the movie frames.
unsigned char* Buffer; // Buffer where you create each frame for a movie or the one frame for a screen shot.
int CaptureWidth, CaptureHeight; // Locked capture size (set when capture starts)
int QualityPreset = 0; // Preset for recording and screenshots: 0=Low, 1=Medium, 2=High, 3=SC

// Used to setup your CUDA device
// These are initialized in SVT.cu/setupCudaEnvironment().
dim3 BlockNodes, GridNodes;
dim3 BlockMuscles, GridMuscles;

// CUDA streams for overlapping memory and kernel operations.
// They are created in SVT.cu/setup(), and destroyed in SVT.cu/Main().
cudaStream_t ComputeStream, MemoryStream;

// To use VBOs for sphere rendering
GLuint SphereVBO, SphereIBO; // Vertex Buffer Object and Index Buffer Object for sphere rendering, Vertex is the sphere's vertices and Index is the order in which to draw them.
GLuint NumSphereVertices, NumSphereIndices; // Number of vertices and indices in the sphere geometry

// This is the node that the beat initiates from.
// It is initially read in form files in the NodesMuscles folder.
// *** Should be stored if a runfile is saved.
int PulsePointNode = -1; // Set to -1 to flag it if it is used before it is set.

// Nodes that orient the simulation. 
// If the node's center of mass is at <0,0,0> and the UpNode is up and FrontNode is in the front looking at you, you should be in the standard view.
// They are initially read in form files in the NodesMuscles folder.
// *** Should be stored if a runfile is saved.
int UpNode = -1; // Set to -1 to flag it if it is used before it is set.
int FrontNode = -1; // Set to -1 to flag it if it is used before it is set.

// Node types: Assigns a number for the different types of tissue. 
// The oder of the number they are assigned is also very important.
// This is the priority that is used to break a tie if a muscle connects
// two different tpyes of nodes. For example if a muscle connects a
// member of the Bachmann's bundle to say a node of standard LA tissue
// the muscle should act like a Bachmann's bundle musle not a standard muscle.
// In the priority assignment the smaller number is the most important.
// They are set here.
const int TypeBachmannBundle = 1;
const int TypePulmonaryVeins = 2;
const int TypeBackWall = 3;
const int TypeMitralValve = 4;
const int TypeAppendage = 5;
const int TypeStandardLA = 6;
const int TypeScarTissue = 7;
const int TypeExtraTissue = 8;
// This is not a tissue type it is where we initiate the beat.
// The tissue type of the pulseNode is BacchannBundle 
// This node just has the extra task of oracstrating the beat.
// We set it to be 100 so we can add addition tissue types above it 
// in the future as needed.
const int TypePulseNode = 100;

// Color types: Assigns a color to each of the tissue type. They are set here.

const float4 ColorBachmannsBundle = {0.2f, 0.2f, 1.0f, 0.0f}; // Blue for Bachmann's Bundle nodes and muscles by default.
const float4 ColorPulmonaryVeins = {1.0f, 0.4f, 0.7f, 0.0f}; // Pink for pulmonary veins nodes and muscles by default.
const float4 ColorBackWall = {0.0f, 1.0f, 0.0f, 0.0f}; // Green for back wall nodes and muscles by default.
const float4 ColorMitralValve = {0.5f, 0.0f, 0.5f, 0.0f}; // Purple for mitral valve nodes and muscles by default.
const float4 ColorAppendage = {1.0f, 0.8f, 0.3f, 0.0f}; // Orange for left atrial appendage nodes and muscles by default.
const float4 ColorStandardLA = {1.0f, 0.0f, 0.0f, 0.0f}; // Red for standard nodes (to reduce contrast)
const float4 ColorScarTissue = {0.6f, 0.6f, 0.6f, 0.0f}; // Gray for scar tissue nodes and muscles by default.
const float4 ColorExtraTissue = {1.0f, 1.0f, 1.0f, 0.0f}; // White for extra tissue nodes and muscles by default.


// Holds the name of the medical view you are in for displaying in the terminal print.
// It is initialized here.
// *** Should be stored if a runfile is saved.
char ViewName[256] = "no view set"; 

// These two variable get user input to adjust muscle refractory periods and conduction velocities when you are
// in AdjustMuscleAreaMode or AdjustMuscleLineMode modes. Once they are read in, they are multiplied by the muscles 
// refractory period and conduction velocity respectively. 
// They are initialized in setNodesAndMuscles.h/setRemainingParameters().
// *** Should be stored if a runfile is saved.
float RefractoryPeriodAdjustmentMultiplier = -1.0; // Set to -1.0 to flag it if it is used before it is set.
float MuscleConductionVelocityAdjustmentMultiplier = -1.0; // Set to -1.0 to flag it if it is used before it is set.

// These are all the globals that are read in from the BasicSimulationSetup file and are explained in detail there.
int NodesMusclesFileOrPreviousRunsFile;
char NodesMusclesFileName[256];
char PreviousRunFileName[256];
float LineWidth;
float NodeRadiusAdjustment;
float NodePointSize;
float4 BackGround;

// These are all the globals that are read in from the IntermediateSimulationSetup file and are explained in detail there.
double BaseMuscleRefractoryPeriod;
double MuscleRefractoryPeriodSTD;
double BaseAbsoluteRefractoryPeriodFraction;
double AbsoluteRefractoryPeriodFractionSTD;
double BaseMuscleConductionVelocity;
double MuscleConductionVelocitySTD;
double BachmannsBundleMultiplier;
double BeatPeriod;
double PrintRate;
int DrawRate;
double Dt;
float4 ReadyColor;
float4 DepolarizingColor;
float4 RepolarizingColor;
float4 RelativeRepolarizingColor;
float4 DeadColor;

// This will hold the radius of the left atrium which we will use to scale the size of everything in the simulation.
// It is calculated in setNodesAndMuscles.h/findRadiusAndMassOfLeftAtrium().
// *** Should be stored if a runfile is saved.
double RadiusOfLeftAtrium = -1.0; // Set to -1.0 to flag it if it is used before it is set.

// Variable that holds mouse locations to be translated into positions in the simulation and mouse other functionality.
// They are initialized in setNodesAndMuscles.h/setRemainingParameters().
double MouseX, MouseY, MouseZ;
int MouseWheelPos;
float HitMultiplier; // Adjusts how big of a region the mouse covers when you are selecting with it.
int ScrollSpeedToggle; // Sets slow or fast scroll speed.
double ScrollSpeed; // How fast your scroll moves.

// Keeps track of the time into the simulation.
// It is initialized in setNodesAndMuscles.h/setRemainingParameters().
// *** Should be stored if a runfile is saved.
double RunTime = -1.0; // Set to -1.0 to flag it if it is used before it is set.

// These keep track of where the view is as you zoom in and out and rotate.
// These are initialized in setNodesAndMuscles.h/setRemainingParameters().
// *** Should be stored if a runfile is saved.
float4 CenterOfSimulation;
float4 AngleOfSimulation;

// Window globals 
// They are all initialized in main().
GLFWwindow* Window; // Window pointer
int XWindowSize;
int YWindowSize; 
double Near; // Front and back of clip planes
double Far;
double EyeX; // Where your eye is
double EyeY;
double EyeZ;
double CenterX; // Where you are looking
double CenterY;
double CenterZ;
double UpX; // What up means to the viewer
double UpY;
double UpZ;
	
// Prototyping functions
int main(int, char**);

// System input and output functions ********************************************************
void readBasicSimulationSetupParameters();
void readIntermediateSimulationSetupParameters();
void readNodesAndMusclesFromBinaryFile();
void saveRun();
void uploadPreviousRun();

// Setup Functions ***********************************************************************
void setSimulationRunDefaults();
void createNewRun();
void setRemainingParameters();
void setupCudaEnvironment();
void setRemainingNodeAndMuscleAttributes();

// Function called by the idle callback. *************************************************
void nBody(double);

// CUDA Functions ***********************************************************************
__device__ void turnOnNodeMusclesGPU(int, int, int, muscleAttributesStructure *, nodeAttributesStructure *);
__global__ void updateNodes(nodeAttributesStructure *, int, int, muscleAttributesStructure *, float, float);
__global__ void updateMuscles(muscleAttributesStructure *, nodeAttributesStructure *, int, int, float, float4, float4, float4, float4);
void cudaErrorCheck(const char *, int);
void copyNodesMusclesToGPU();
void copyNodesMusclesFromGPU();
void copyNodesFromGPU();
void copyNodesToGPU();
 
// Viewing Functions ***********************************************************************
void showMuscleTypes();
void showTooltip(const char *);
void renderSphere(float, int, int);
void createSphereVBO(float, int, int);
void renderSphereVBO();
void frustumView();
void drawPicture();
void createGUI();

// Callback Functions ***********************************************************************
 void reshape(GLFWwindow* window, int width, int height);
 void mouseFunctionsOff();
 void mouseAblateMode();
 void mouseEctopicBeatMode();
 void mouseAdjustMusclesAreaMode();
 void mouseAdjustMusclesLineMode();
 void mouseIdentifyNodeMode();
 void mouseIdentifyMuscleMode();
 bool setMouseMuscleAttributes();
 void setEctopicBeat(int nodeId);
 void movieOn();
 void movieOff();
 void screenShot();
 void KeyPressed(GLFWwindow* window, int key, int scancode, int action, int mods);
 void keyHeld(GLFWwindow* window);
 void mousePassiveMotionCallback(GLFWwindow* window, double x, double y);
 void myMouse(GLFWwindow* window, int button, int state, double x, double y);
 void scrollWheel(GLFWwindow*, double, double);
 
 // Utility Functions ***********************************************************************
 double findAverageRadiusOfLeftAtrium();
 void checkMuscle(int);
 double croppedRandomNumber(double, double, double);
 float4 findCenterOfObject();
 void centerObject();
 void translateObject(float, float, float);
 void rotateXAxis(float);
 void rotateYAxis(float);
 void rotateZAxis(float);
 string getTimeStamp();
 
 //*****************************************************************************************************************************************
	
