// Local include files
#include "./header.h"
#include "./callBackFunctions.cu"
#include "./viewDrawAndTerminalFunctions.cu"

/*
 The main function:
 Reads to user setup file inputs, setsup the invoronment and kicks off the GUI loop.
*/
int main(int argc, char** argv)
{
	// Getting user inputs.
	readBasicSimulationSetupParameters();
	readIntermediateSimulationSetupParameters();
	generalSimulationSetup();

	if(!glfwInit()) // Initialize GLFW, check for failure
	{
	fprintf(stderr, "Failed to initialize GLFW\n");
	return -1;
}

	// Set compatibility mode to allow legacy OpenGL (this is just standard)
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2); //these 2 lines are for compatibility with older versions of OpenGL (2.1+) ensures backwards compatibility
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_ANY_PROFILE); //this line is for compatibility with older versions of OpenGL

	// Create a windowed mode window and its OpenGL context
	Window = glfwCreateWindow(XWindowSize, YWindowSize, "SVT", NULL, NULL); // args: width, height, title, monitor, share
	if (!Window) 
	{
		fprintf(stderr, "Failed to create window\n");
		return -1;
	}

	// Make the window's context current
	glfwMakeContextCurrent(Window); // Make the window's context current, meaning that all future OpenGL commands will apply to this window
	glfwSwapInterval(1); // Enable vsync (1 = on, 0 = off), vsync is a method used to prevent screen tearing which occurs when the GPU is rendering frames at a rate faster than the monitor can display them

	if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))  // Initialize GLAD, check for failure
	{
		fprintf(stderr, "Failed to initialize GLAD\n");
		glfwTerminate();
		return -1;
	}

	glfwSetInputMode(Window, GLFW_STICKY_KEYS, GLFW_TRUE);
	glfwSetInputMode(Window, GLFW_REPEAT, GLFW_TRUE);  // Explicitly enable key repeat

	//create a sphere VBO for drawing the nodes (since allnodes are the same we create one VBO and use it for all nodes)
	createSphereVBO(NodeRadiusAdjustment * RadiusOfLeftAtrium, 20, 20); //the first arg was the radius used in the draw nodes flag

	//these set up our callbacks, most have been changed to adapters until GUI is implemented
	glfwSetFramebufferSizeCallback(Window, reshape);  //sets the callback for the window resizing
	glfwSetCursorPosCallback(Window, mousePassiveMotionCallback); //sets the callback for the cursor position
	glfwSetMouseButtonCallback(Window, myMouse); //sets the callback for the mouse clicks
	glfwSetScrollCallback(Window, scrollWheel); //sets the callback for the mouse wheel
	glfwSetKeyCallback(Window, KeyPressed); //sets the callback for the keyboard
	
	// Set the clear color to the background color
	glClearColor(BackGround.x, BackGround.y, BackGround.z, 1.0f);

	//Lighting and material properties
	glEnable(GL_LIGHTING);
	glEnable(GL_LIGHT0);
	//GLfloat light_position[] = {EyeX, EyeY, EyeZ, 0.0};
	GLfloat light_position[] = {1.0, 1.0, 1.0, 0.0}; //where the light is: {x,y,z,w}, w=0.0 is infinite light aiming at x,y,z, w=1.0 is a point light radiating from x,y,z
	GLfloat light_ambient[]  = {0.35, 0.35, 0.35, 1.0}; //what color is the ambient light, {r,g,b,a}, a= opacity 1.0 is fully visible, 0.0 is invisible
	GLfloat light_diffuse[]  = {0.35, 0.35, 0.35, 1.0}; //does light reflect off of the object, {r,g,b,a}, a has no effect
	GLfloat light_specular[] = {1.0, 1.0, 1.0, 1.0}; //does light highlight shiny surfaces, {r,g,b,a}. i.e what light reflects to viewer
	GLfloat lmodel_ambient[] = {0.5, 0.5, 0.5, 1.0}; //global ambient light, {r,g,b,a}, applies uniformly to all objects in the scene
	GLfloat mat_specular[]   = {1.0, 1.0, 1.0, 1.0}; //reflective properties of an object, {r,g,b,a}, highlights are currently white
	GLfloat mat_shininess[]  = {64.0}; //how shiny is the surface of an object, 0.0 is dull, 128.0 is very shiny
	glShadeModel(GL_SMOOTH);
	glColorMaterial(GL_FRONT, GL_AMBIENT_AND_DIFFUSE);
	glLightfv(GL_LIGHT0, GL_POSITION, light_position);
	glLightfv(GL_LIGHT0, GL_AMBIENT, light_ambient);
	glLightfv(GL_LIGHT0, GL_DIFFUSE, light_diffuse);
	glLightfv(GL_LIGHT0, GL_SPECULAR, light_specular);
	glLightModelfv(GL_LIGHT_MODEL_AMBIENT, lmodel_ambient);
	glMaterialfv(GL_FRONT, GL_SPECULAR, mat_specular);
	glMaterialfv(GL_FRONT, GL_SHININESS, mat_shininess);

	glEnable(GL_COLOR_MATERIAL);
	glEnable(GL_DEPTH_TEST);

	//*****************************************Set up GUI********************************
	// Initialize ImGui
	IMGUI_CHECKVERSION();
	ImGui::CreateContext();
	ImGuiIO& io = ImGui::GetIO(); (void)io;
	io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;  // Enable keyboard controls

	// Setup ImGui style
	ImGui::StyleColorsDark();  // Choose a style (Light, Dark, or Classic)
	ImGuiStyle& style = ImGui::GetStyle(); // Get the current style
	style.Colors[ImGuiCol_WindowBg].w = 1.0f;  // Set window background color

	// Setup Platform/Renderer backends
	ImGui_ImplGlfw_InitForOpenGL(Window, true);  //connect ImGui to GLFW
	ImGui::GetIO().ConfigFlags |= ImGuiConfigFlags_NavNoCaptureKeyboard; //prevent ImGui from capturing keyboard input, allowing GLFW to handle it instead
	ImGui_ImplOpenGL3_Init("#version 130");      //Chooses OpenGL version 3.0, this is the version that is compatible with the current version of ImGui

	// Load a font
	io.Fonts->AddFontDefault();

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);


	//*****************************************End GUI Setup********************************

	//Initialize the window with aspect ratio and projection matrix

	/*
		NOTE: 

		the reshape function which calculated the aspect ratio and projection matrix to allow us to resize without changing the aspect ratio
		caused the simulation to not display properly when the window was first created and would stay that way until the window was resized.

		and calling resize didn't work, so I basically copied everything here and got the window size instead of XWindowSize and YWindowSize
		because X and Y windows size don't work for this

	*/
	// Get current size
	int width, height;
	glfwGetFramebufferSize(Window, &width, &height);
    
	// Update stored window size and set initial render size
	XWindowSize = width;
	YWindowSize = height;
	// Initialize capture size to the current window size so screenshots work before any capture starts
	CaptureWidth = XWindowSize;
	CaptureHeight = YWindowSize;

	// Reset viewport and matrices to ensure proper initial state
	glViewport(0, 0, XWindowSize, YWindowSize);
    
	// Reset projection matrix
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();

	// Calculate aspect ratio using the render size
	float aspect = (float)XWindowSize / (float)YWindowSize;

	// Set projection based on the view flag
	if(Simulation.ViewFlag == 0) // Orthogonal view
	{
		glOrtho(-aspect, aspect, -1.0, 1.0, -1.0, 1.0); // Orthographic projection
	}
	else // Frustum view
	{
		glFrustum(-aspect, aspect, -1.0, 1.0, Near, Far); // Perspective projection
	}
	
   	// Reset modelview matrix
	// MODELVIEW MATRIX - this controls camera position
   	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity(); //Necessary here
	gluLookAt(EyeX, EyeY, EyeZ, CenterX, CenterY, CenterZ, UpX, UpY, UpZ);

	// Draw once to initialize everything
	drawPicture();
	glfwSwapBuffers(Window);
	// Main loop
	while (!glfwWindowShouldClose(Window))
	{
		glfwPollEvents();

		keyHeld(Window); // Handle key hold events

		// Start ImGui frame
		ImGui_ImplOpenGL3_NewFrame();
		ImGui_ImplGlfw_NewFrame();

		ImGui::NewFrame();
		
		// Update physics --multiple steps per frame for performance
		if (!Simulation.isPaused) 
		{
			// Execute nBody DrawRate times before we draw
			for (int i = 0; i < DrawRate; i++) 
			{
				nBody(Dt);
			}
		}
		
		// Always draw every frame - this is critical for GLFW performance
		cudaStreamSynchronize(ComputeStream); 
		copyNodesMusclesFromGPU();
		drawPicture();
		
		// Create and render GUI
		createGUI();
		ImGui::Render();
		ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
		
		// Swap buffers
		glfwSwapBuffers(Window);
	}
		
	//Destroy streams
	cudaStreamDestroy(ComputeStream);
  	cudaStreamDestroy(MemoryStream);

	//delete the state file if it exists
	remove("simulation_state.bin");

	//free memory
	cudaFreeHost(Node);
	cudaFreeHost(Muscle);
	cudaFree(NodeGPU);
	cudaFree(MuscleGPU);

	//shutdown ImGui
	ImGui_ImplOpenGL3_Shutdown();
	ImGui_ImplGlfw_Shutdown();
	ImGui::DestroyContext();

	//destroy the window and terminate GLFW
	glfwDestroyWindow(Window);
  	glfwTerminate();

	return 0;
}

// System input and output functions ********************************************************

/*
 This function reads in all the user defined parameters in the BasicSimulationSetup file.
*/
void readBasicSimulationSetupParameters()
{
	ifstream data;
	string name;
	
	data.open("./BasicSimulationSetup");
	if(data.is_open() == 1)
	{
		getline(data,name,'=');
		data >> NodesMusclesFileOrPreviousRunsFile;
		
		getline(data,name,'=');
		data >> NodesMusclesFileName;
		
		getline(data,name,'=');
		data >> PreviousRunFileName;
		
		getline(data,name,'=');
		data >> LineWidth;
		
		getline(data,name,'=');
		data >> NodeRadiusAdjustment;
		
		getline(data,name,'=');
		data >> NodePointSize;
		
		getline(data,name,'=');
		data >> BackGround.x;
		
		getline(data,name,'=');
		data >> BackGround.y;
		
		getline(data,name,'=');
		data >> BackGround.z;
	}
	else
	{
		printf("\n\n Could not open BasicSimulationSetup file.");
		printf("\n The simulation has been terminated.\n\n");
		exit(0);
	}
	
	data.close();
	printf("\n Basic Simulation Parameters have been read in from BasicSimulationSetup file.\n");
}

/*
 This function reads in all the user defined parameters in the IntermediateSimulationSetup file.
*/
void readIntermediateSimulationSetupParameters()
{
	ifstream data;
	string name;
	
	data.open("./IntermediateSimulationSetup");
	if(data.is_open() == 1)
	{
		getline(data,name,'=');
		data >> BaseMuscleRefractoryPeriod;
		
		getline(data,name,'=');
		data >> MuscleRefractoryPeriodSTD;
		        
		getline(data,name,'=');
		data >> BaseAbsoluteRefractoryPeriodFraction;
		
		getline(data,name,'=');
		data >> AbsoluteRefractoryPeriodFractionSTD;
		
		getline(data,name,'=');
		data >> BaseMuscleConductionVelocity;
		
		getline(data,name,'=');
		data >> MuscleConductionVelocitySTD; 
		
		getline(data,name,'=');
		data >> BachmannsBundleMultiplier;
		
		getline(data,name,'=');
		data >> BeatPeriod;
		
		getline(data,name,'=');
		data >> PrintRate;
		
		getline(data,name,'=');
		data >> DrawRate;
		
		getline(data,name,'=');
		data >> Dt;
		
		getline(data,name,'=');
		data >> ReadyColor.x;
		
		getline(data,name,'=');
		data >> ReadyColor.y;
		
		getline(data,name,'=');
		data >> ReadyColor.z;
		
		getline(data,name,'=');
		data >> DepolarizingColor.x;
		
		getline(data,name,'=');
		data >> DepolarizingColor.y;
		
		getline(data,name,'=');
		data >> DepolarizingColor.z;
		
		getline(data,name,'=');
		data >> RepolarizingColor.x;
		
		getline(data,name,'=');
		data >> RepolarizingColor.y;
		
		getline(data,name,'=');
		data >> RepolarizingColor.z;
		
		getline(data,name,'=');
		data >> RelativeRepolarizingColor.x;
		
		getline(data,name,'=');
		data >> RelativeRepolarizingColor.y;
		
		getline(data,name,'=');
		data >> RelativeRepolarizingColor.z;
		
		getline(data,name,'=');
		data >> DeadColor.x;
		
		getline(data,name,'=');
		data >> DeadColor.y;
		
		getline(data,name,'=');
		data >> DeadColor.z;
	}
	else
	{
		printf("\n\n Could not open IntermediateSimulationSetup file.");
		printf("\n The simulation has been terminated.\n\n");
		exit(0);
	}
	
	data.close();
	printf("\n Intermediate Simulation Parameters have been read in from IntermediateSimulationSetup file.\n");
}

/*
 This function reads node and muscle data from a config-exported binary file.
 It appends the binary values into the existing model structs by filling fields
 that already exist in this model's node and muscle structures.
*/
void readNodesAndMusclesFromBinaryFile()
{
	FILE *inFile;
	char fileName[512];
	char *dot;
	struct stat fileStat;

	// Build the expected input path under the binary folder.
	strcpy(fileName, "./ModelNodesMuscles/");
	strcat(fileName, NodesMusclesFileName);

	// Enforce .bin extension for early detection of invalid file names and to avoid confusion with raw files
	dot = strrchr(NodesMusclesFileName, '.');
	if(dot == NULL || strcmp(dot, ".bin") != 0)
	{
		printf("\n\n Invalid binary input file name %s.", NodesMusclesFileName);
		printf("\n InputFileName in BasicSimulationSetup must end with .bin");
		printf("\n If you are trying to read in a raw file, make sure you run it through the config program and save it as a .bin file.");
		printf("\n To run the config program, run the command: ./runconfig in the terminal");
		printf("\n The simulation has been terminated.\n\n");
		exit(0);
	}

	// Check that the file physically exists before trying to open it.
	if(stat(fileName, &fileStat) != 0)
	{
		printf("\n\n Binary file %s does not exist.", fileName);
		printf("\n The simulation has been terminated.\n\n");
		exit(0);
	}

	// Open in binary read mode.
	inFile = fopen(fileName, "rb");
	if(inFile == NULL)
	{
		printf("\n\n Can't open binary file %s.", fileName);
		printf("\n The simulation has been terminated.\n\n");
		exit(0);
	}

	// Read and validate format version before reading any payload.
	int version = 0;
	fread(&version, sizeof(int), 1, inFile);
	if(version != 1)
	{
		printf("\n\n Unsupported binary version %d in %s.", version, fileName);
		printf("\n The simulation has been terminated.\n\n");
		exit(0);
	}

	// Read global counts and orientation references
	fread(&NumberOfNodes, sizeof(int), 1, inFile);
	fread(&NumberOfMuscles, sizeof(int), 1, inFile);
	fread(&PulsePointNode, sizeof(int), 1, inFile);
	fread(&UpNode, sizeof(int), 1, inFile);
	fread(&FrontNode, sizeof(int), 1, inFile);

	printf("\n NumberOfNodes = %d", NumberOfNodes);
	printf("\n NumberOfMuscles = %d", NumberOfMuscles);
	printf("\n PulsePointNode = %d", PulsePointNode);
	printf("\n UpNode = %d", UpNode);
	printf("\n FrontNode = %d", FrontNode);

	// Allocate and initialize node structs with model defaults.
	cudaHostAlloc((void**)&Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaHostAllocDefault);
	cudaErrorCheck(__FILE__, __LINE__);
	cudaMalloc((void**)&NodeGPU, NumberOfNodes*sizeof(nodeAttributesStructure));
	cudaErrorCheck(__FILE__, __LINE__);

	// Zeroing out and intializing the nodes for safty before they are read in.
	for(int i = 0; i < NumberOfNodes; i++)
	{
		Node[i].type = -1;
		Node[i].position.x = 0.0;
		Node[i].position.y = 0.0;
		Node[i].position.z = 0.0;
		Node[i].position.w = 0.0;

		Node[i].isBeatNode = false;
		Node[i].beatPeriod = -1.0;
		Node[i].beatTimer = -1.0;
		Node[i].isFiring = false;
		Node[i].isAblated = false;
		Node[i].isDrawNode = false;

		Node[i].color.x = 0.0;
		Node[i].color.y = 1.0;
		Node[i].color.z = 0.0;
		Node[i].color.w = 0.0;

		for(int j = 0; j < MUSCLES_PER_NODE; j++)
		{
			Node[i].muscle[j] = -1;
		}
	}

	// Read nodes in exact order used by config saveBinary().
	for(int i = 0; i < NumberOfNodes; i++)
	{
		fread(&Node[i].type, sizeof(int), 1, inFile);
		fread(&Node[i].position, sizeof(float4), 1, inFile);
		fread(Node[i].muscle, sizeof(int), MUSCLES_PER_NODE, inFile);
		fread(&Node[i].color, sizeof(float4), 1, inFile);
	}

	// Allocate and initialize muscle structs with model defaults.
	cudaHostAlloc((void**)&Muscle, NumberOfMuscles*sizeof(muscleAttributesStructure), cudaHostAllocDefault);
	cudaErrorCheck(__FILE__, __LINE__);
	cudaMalloc((void**)&MuscleGPU, NumberOfMuscles*sizeof(muscleAttributesStructure));
	cudaErrorCheck(__FILE__, __LINE__);

	// Intializing the muscles for safty before they are read in.
	for(int i = 0; i < NumberOfMuscles; i++)
	{
		Muscle[i].type = -1;
		Muscle[i].nodeA = -1;
		Muscle[i].nodeB = -1;
		Muscle[i].apNode = -1;
		Muscle[i].isOn = false;
		Muscle[i].isEnabled = true;
		Muscle[i].timer = -1.0;
		Muscle[i].naturalLength = -1.0;
		//Muscle[i].compressionStopFraction = -1.0;
		Muscle[i].conductionVelocity = -1.0;
		Muscle[i].conductionDuration = -1.0;
		Muscle[i].refractoryPeriod = -1.0;
		Muscle[i].absoluteRefractoryPeriodFraction = -1.0;
		Muscle[i].color.x = 1.0;
		Muscle[i].color.y = 0.0;
		Muscle[i].color.z = 0.0;
		Muscle[i].color.w = 0.0;
	}

	// Read muscles in exact order used by config saveBinary().
	for(int i = 0; i < NumberOfMuscles; i++)
	{
		fread(&Muscle[i].type, sizeof(int), 1, inFile);
		fread(&Muscle[i].nodeA, sizeof(int), 1, inFile);
		fread(&Muscle[i].nodeB, sizeof(int), 1, inFile);
		fread(&Muscle[i].naturalLength, sizeof(float), 1, inFile);
		fread(&Muscle[i].color, sizeof(float4), 1, inFile);
	}

	//close file and print success message.
	fclose(inFile);
	printf("\n Binary file %s has been read in.\n", fileName);
}

/*
 This function loads all the node and muscle attributes from a previous run file that was saved.
*/
void getNodesandMusclesFromPreviousRun()
{
	FILE *inFile;
	char fileName[256];
	
	strcpy(fileName, "");
	strcat(fileName,"./PreviousRunsFile/");
	strcat(fileName,PreviousRunFileName);
	strcat(fileName,"/run");

	inFile = fopen(fileName,"rb");
	if(inFile == NULL)
	{
		printf("\n\n Can't open PreviousRunsFile %s.", fileName);
		printf("\n The simulation has been terminated.\n\n");
		exit(0);
	}

	//settingFile = fopen("run", "wb");
  	
        fread(&NumberOfNodes, sizeof(int), 1, inFile);
        // Creating memory space for the nodes on the CPU and GPU
        cudaHostAlloc(&Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaHostAllocDefault); // Making page locked memory on the CPU.
        cudaErrorCheck(__FILE__, __LINE__);
        cudaMalloc((void**)&NodeGPU, NumberOfNodes*sizeof(nodeAttributesStructure));
        cudaErrorCheck(__FILE__, __LINE__);
        fread(Node, sizeof(nodeAttributesStructure), NumberOfNodes, inFile);
  	
        int linksPerNode = MUSCLES_PER_NODE;
        fread(&linksPerNode, sizeof(int), 1, inFile);
        if(linksPerNode != MUSCLES_PER_NODE)
        {
              printf("\n\n The number Of muscle per node do not match.");
              printf("\n You will have to set the #define MUSCLES_PER_NODE");
              printf("\n to %d in header.h then recompile the code.", linksPerNode);
              printf("\n The simulation has been terminated.\n\n");
              exit(0);
        }
  	
        fread(&NumberOfMuscles, sizeof(int), 1, inFile);
        // Creating memory space for the muscles on the CPU and GPU
        cudaHostAlloc(&Muscle, NumberOfMuscles*sizeof(muscleAttributesStructure), cudaHostAllocDefault); // Making page locked memory on the CPU.
        cudaErrorCheck(__FILE__, __LINE__);
        cudaMalloc((void**)&MuscleGPU, NumberOfMuscles*sizeof(muscleAttributesStructure));
        cudaErrorCheck(__FILE__, __LINE__);
        fread(Muscle, sizeof(muscleAttributesStructure), NumberOfMuscles, inFile);

  	// To keep the contraction state what was readin from the BasicSimulationSetup file not what the state was
  	// when the simulation was saved we save it in a temp, overwrite it then restore it.
        fread(&Simulation, sizeof(Simulation), 1, inFile);
  	
        fread(&PulsePointNode, sizeof(int), 1, inFile);
        fread(&UpNode, sizeof(int), 1, inFile);
        fread(&FrontNode, sizeof(int), 1, inFile);
  	
        fread(&ViewName, sizeof(char), 256, inFile);
  	
        fread(&RefractoryPeriodAdjustmentMultiplier, sizeof(float), 1, inFile);
        fread(&MuscleConductionVelocityAdjustmentMultiplier, sizeof(float), 1, inFile);
        
        fread(&RadiusOfLeftAtrium, sizeof(double), 1, inFile);
        //fread(&MassOfLeftAtrium, sizeof(double), 1, inFile);
        //fread(&MyocyteForcePerMassFraction, sizeof(double), 1, inFile);
  	
        fread(&CenterOfSimulation, sizeof(float4), 1, inFile);
        fread(&AngleOfSimulation, sizeof(float4), 1, inFile);
        
        fread(&RunTime, sizeof(double), 1, inFile);
        
	fclose(inFile);
	
	printf("\n Nodes and Muscles have been read in from %s.\n", fileName);	
}
		
// Run setup Functions *********************************************************************** 
/*
 This function calls all the functions that are used to setup the nodes muscles and initial parameters 
 of the simulation.
*/
void generalSimulationSetup()
{	
	// Seeding the random number generator.
	time_t t;
	srand((unsigned) time(&t));
		
	// Getting nodes and muscle from files or a previous run file.
	if(NodesMusclesFileOrPreviousRunsFile == 0)
	{
		printf("\n Rad = %lf.\n\n",RadiusOfLeftAtrium );
		readNodesAndMusclesFromBinaryFile();
		RadiusOfLeftAtrium = findAverageRadiusOfLeftAtrium();
		setRemainingNodeAndMuscleAttributes();
		for(int i = 0; i < NumberOfMuscles; i++)
		{	
			checkMuscle(i);
		}
	}
	else if(NodesMusclesFileOrPreviousRunsFile == 1)
	{
		getNodesandMusclesFromPreviousRun();
	}
	else
	{
		printf("\n\n Bad NodesMusclesFileOrPreviousRunsFile type %d.", NodesMusclesFileOrPreviousRunsFile);
		printf("\n The simulation has been terminated.\n\n");
		exit(0);
	}
	
	// Setting parameters that are not initially read from the node and muscle or previous run file.
	setRemainingParameters();

	// Sending all the info that we have just created to the GPU so it can start crunching numbers.
	setupCudaEnvironment();
	copyNodesMusclesToGPU();
	
	printf("\n\n Have a good simulation.\n\n");
}

/*
 This function sets any remaining parameters that are not part of the nodes or muscles structures.
 It also sets or initializes the run parameters for this run.
*/
void setRemainingParameters()
{
	if(RadiusOfLeftAtrium < 0.0)
	{
		printf("\n\n You are trying to set window ziew parameters before the RadiusOfLeftAtrium is set.");
		printf("\n The simulation has been terminated.\n\n");
		exit(0);
	}
	XWindowSize = 1800; //1800
	YWindowSize = 1000; //1000

	// Clip plains
	Near = 2.0;
	Far = 400.0; // 80.0*RadiusOfLeftAtrium;

	//Where your eye is located
	EyeX = 0.0*RadiusOfLeftAtrium;
	EyeY = 0.0*RadiusOfLeftAtrium;
	EyeZ = 2.0*RadiusOfLeftAtrium;

	//Where you are looking
	CenterX = 0.0;
	CenterY = 0.0;
	CenterZ = 0.0;

	//Up vector for viewing
	UpX = 0.0;
	UpY = 1.0;
	UpZ = 0.0;
	
	// If this is a new run these values are set hre. If it is a previous run these values will aready be read in.
	if (NodesMusclesFileOrPreviousRunsFile == 0) 
	{
		RunTime = 0.0;

		RefractoryPeriodAdjustmentMultiplier = 1.0;
		MuscleConductionVelocityAdjustmentMultiplier = 1.0;

		CenterOfSimulation.x = 0.0;
		CenterOfSimulation.y = 0.0;
		CenterOfSimulation.z = 0.0;
		CenterOfSimulation.w = 0.0;

		AngleOfSimulation.x = 0.0;
		AngleOfSimulation.y = 1.0;
		AngleOfSimulation.z = 0.0;
		AngleOfSimulation.w = 0.0;

		Simulation.isPaused = true;
		Simulation.isInAblateMode = false;
		Simulation.isInEctopicBeatMode = false;
		Simulation.isInEctopicEventMode = false;
		Simulation.isInAdjustMuscleAreaMode = false;
		Simulation.isInAdjustMuscleLineMode = false;
		Simulation.isInFindNodeMode = false;
		Simulation.isInMouseFunctionMode = false;
		Simulation.isRecording = false;
		Simulation.ViewFlag = 1;
		Simulation.DrawNodesFlag = 0;
		Simulation.DrawFrontHalfFlag = 0;
		Simulation.ShowMuscleTypesFlag = false;
		Simulation.nodesFound = false;
		Simulation.frontNodeIndex = -1;
		Simulation.topNodeIndex = -1;
		// Simulation.guiCollapsed = false; //This is set in viewDrawAndTerminalFuctions.h/createGUI().
	}
	
	HitMultiplier = 0.03;
	MouseZ = RadiusOfLeftAtrium;
	MouseX = 0.0;
	MouseY = 0.0;
	ScrollSpeedToggle = 1;
	ScrollSpeed = 1.0;
	MouseWheelPos = 0;
}

/*
 Setting up the CUDA environment. We have three:
 1: Node based
 2: Muscle based
*/
void setupCudaEnvironment()
{
	// 1:
	BlockNodes.x = BLOCKNODES;
	BlockNodes.y = 1;
	BlockNodes.z = 1;
	
	GridNodes.x = (NumberOfNodes - 1)/BlockNodes.x + 1;
	GridNodes.y = 1;
	GridNodes.z = 1;
	
	// 2:
	BlockMuscles.x = BLOCKMUSCLES;
	BlockMuscles.y = 1;
	BlockMuscles.z = 1;
	
	GridMuscles.x = (NumberOfMuscles - 1)/BlockMuscles.x + 1;
	GridMuscles.y = 1;
	GridMuscles.z = 1;
	
	//create CUDA streams for async memory copy and compute
	cudaStreamCreate(&ComputeStream);
	cudaStreamCreate(&MemoryStream);
}

/*
 In this function, we set the remaining value of the nodes and muscles.
 1: Checking to make sure LA radius and mass are set before we use them to set Node and Muscle attributes.
 2: Setting the pulse point node.
 3: Then, we find the length of each individual muscle and sum these up to find the total length of all muscles that represent
    the left atrium. 
 4: This allows us to find the fraction of a single muscle's length compared to the total muscle lengths. We can now multiply this 
    fraction by the mass of the left atrium to get the mass on an individual muscle. 
 6: Here we set the base muscle attributes. 
    a: Setting the muscles conduction velocity. 
    b: Setting the muscles conduction duration (How long it takes for a signal to travel across the muscle).
    c: Setting the muscle's refractory period.
    d: Setting the muscle's absolute refractory period.
    e: Setting the muscle's contraction strength.
      The myocyte force per mass ratio is calculated by treating a myocyte as a cylinder. 
      In the for loop we add some small random fluctuations to these values so the simulation can have some stochastic behavior. 
      If you do not want any stochastic behavior simply set MyocyteForcePerMassSTD to zero in the simulationsetup file.
      The strength is also scaled using the scaling read in from the simulationSetup file. The scaling is used so the user
      can adjust the standard muscle attributes to perform as desired in their simulation. A value of 1.0 adds no scaling.
    f: Setting the muscle's compression stop fraction (The max percent of the muscles length that is lost in contraction).
     Note: Muscles do not have mass in the simulation. All the mass is carried in the nodes. Muscles were given mass here to be able to
     generate the node masses and area. We carry the muscle masses forward in the event that we need to generate a muscle ratio in 
     future updates to the program. 
 7: Setting all the atributes of BB. 
 8: Setting all the atributes of the LAA.
 9: Setting all the atributes of the PV.
*/
void setRemainingNodeAndMuscleAttributes()
{	
	// 1:
	if(RadiusOfLeftAtrium < 0.0) // It is intiallized at -1.0.
	{
	      printf("\n You are trying to set Node and Muscle attributes before LA radius has been set.");
	      printf("\n The simulation has been terminated.\n\n");
	      exit(0);
	}
	
	// 2: This is the pulse point node that generates the beat.
	Node[PulsePointNode].isBeatNode = true;
	Node[PulsePointNode].beatPeriod = BeatPeriod;
	Node[PulsePointNode].beatTimer = BeatPeriod; // Set the time to BeatPeriod so it will kickoff a beat as soon as it starts.
	
	// 3:
	double dx, dy, dz, d;
	double totalLengthOfAllMuscles = 0.0;
	for(int i = 0; i < NumberOfMuscles; i++)
	{	
		dx = Node[Muscle[i].nodeA].position.x - Node[Muscle[i].nodeB].position.x;
		dy = Node[Muscle[i].nodeA].position.y - Node[Muscle[i].nodeB].position.y;
		dz = Node[Muscle[i].nodeA].position.z - Node[Muscle[i].nodeB].position.z;
		d = sqrt(dx*dx + dy*dy + dz*dz);
		Muscle[i].naturalLength = d; // The natural length is how far apart its two ends are at rest.
		totalLengthOfAllMuscles += d;
	}
	
	// 6:
	double stddev, left, right;
	for(int i = 0; i < NumberOfMuscles; i++)
	{	
	        // a: Setting the muscles conduction velocity.
		stddev = MuscleConductionVelocitySTD;
		left = -MuscleConductionVelocitySTD;
		right = MuscleConductionVelocitySTD;
		Muscle[i].conductionVelocity = BaseMuscleConductionVelocity + croppedRandomNumber(stddev, left, right);
		
		// b: Setting the muscles conduction duration (How long it takes for a signal to travel across the muscle).
		Muscle[i].conductionDuration = Muscle[i].naturalLength/Muscle[i].conductionVelocity;
		
		// c: Setting the muscle's refractory period.
		stddev = MuscleRefractoryPeriodSTD;
		left = -MuscleRefractoryPeriodSTD;
		right = MuscleRefractoryPeriodSTD;	
		Muscle[i].refractoryPeriod = BaseMuscleRefractoryPeriod + croppedRandomNumber(stddev, left, right);
		
		// d: Setting the muscle's absolute refractory period.
		stddev = AbsoluteRefractoryPeriodFractionSTD;
		left = -AbsoluteRefractoryPeriodFractionSTD;
		right = AbsoluteRefractoryPeriodFractionSTD;
		Muscle[i].absoluteRefractoryPeriodFraction = BaseAbsoluteRefractoryPeriodFraction + croppedRandomNumber(stddev, left, right);
	}
	
	
	int typeLA = 0;
	int typeBB = 1;
	int typeLAA = 2;
	int typeScar = 3;
	int typePV = 4;
	int typeMV = 5;
	for(int i = 0; i < NumberOfNodes; i++)
	{
		if(Node[i].type == typeLA)
		{
			//LA.
		}
		else if(Node[i].type == typeBB)
		{

			Node[i].isDrawNode = true;
		}
		else if(Node[i].type == typeLAA)
		{
			Node[i].isDrawNode = true;
		}
		else if(Node[i].type == typeScar)
		{
			Node[i].isAblated = true;
			Node[i].isDrawNode = true;
		}
		else if(Node[i].type == typePV)
		{
			Node[i].isDrawNode = true;
		}
		else if(Node[i].type == typeMV)
		{
			Node[i].isDrawNode = true;
		}
	}
	
	for(int i = 0; i < NumberOfMuscles; i++)
	{
		if(Muscle[i].type == typeLA)
		{
			//LA do nothing.
		}
		else if(Muscle[i].type == typeBB)
		{
			Muscle[i].conductionDuration /= BachmannsBundleMultiplier;
		}
		else if(Muscle[i].type == typeLAA)
		{
			//
		}
		else if(Muscle[i].type == typeScar)
		{
			//
		}
		else if(Muscle[i].type == typePV)
		{
			//
		}
		else if(Muscle[i].type == typeMV)
		{
			//
		}
	}
	
	for(int i = 0; i < NumberOfMuscles; i++)
	{
		if(Muscle[i].type == typeLAA)
		{
			// Adjust speed on LAA vector
		}
		else
		{
			// Adjust speed on LA vector
		}
	}

	printf("\n All node and muscle attributes have been set.\n");
}

/*
 This function is called by the openGL idle function. Hence this function is called every time openGL is not doing anything else,
 which is most of the time.
 This function orchestrates the simulation by;
 1: Calling the getForces function which gets all the forces except the drag force on all nodes.
 2: Calling the upDateNodes function which moves the nodes based off of the forces from the getForces function.
    It uses the leap-frog formulas to integrate the nodes forward in time. It also sees if a node is a beat node  
    and if it needs to send out a signal.
 3: Calling the updateMuscles function to adjust where they are in their cycle and react accordingly.
 4: Sees if it is time to recenter the simulation.
 5: Sees if simulation needs to be redrawn to the screen.
 6: Sees if the terminal screen needs to be updated.
 
 Note: If Pause is on it skips all this and if Contraction is not on it skips all of its moving calculations
 and only performs calculations that deal with electrical conduction and muscle timing. 
*/
void nBody(double dt)
{	
	//no need to check if we're paused because we handle that in main

	updateNodes<<<GridNodes, BlockNodes, 0, ComputeStream>>>(NodeGPU, NumberOfNodes, MUSCLES_PER_NODE, MuscleGPU, dt, RunTime);
	cudaErrorCheck(__FILE__, __LINE__);

	updateMuscles<<<GridMuscles, BlockMuscles, 0, ComputeStream>>>(MuscleGPU, NodeGPU, NumberOfMuscles, NumberOfNodes, dt, ReadyColor, DepolarizingColor, RepolarizingColor, RelativeRepolarizingColor);
	cudaErrorCheck(__FILE__, __LINE__);
	
	RunTime += dt;
}


// CUDA Functions **************************************************************************

/*
 This CUDA function tries to turn on every muscle that is connected to a node.
 It loops through all the muscle connected to the node with index = nodeToTurnOn.
 1: Checks to see if it really is a muscle (muscle number not equal to -1).
    and Checks to see if the muscle is on or off. If it is off it is ready to turn on. 
    There is no need to see if a muscle is dead here because if it is dead turning it on will do nothing.
    Then it: 
 	a. Sets which node turned it on so it can send the conduction signal in the proper direction. 
 	b. Sets the muscle to on.
 	c. Sets the muscle's timer to 0.0.
*/
__device__ void turnOnNodeMusclesGPU(int nodeToTurnOn, int numberOfNodes, int musclesPerNode, muscleAttributesStructure *muscle, nodeAttributesStructure *node)
{
	int muscleNumber;
	
	for(int j = 0; j < musclesPerNode; j++) // Looping through all muscle connected to this node.
	{
		muscleNumber = node[nodeToTurnOn].muscle[j];
		
		// 1: Is this a legit muscle and is it ready to turn on.
		if((muscleNumber != -1) && (!muscle[muscleNumber].isOn))
		{
			muscle[muscleNumber].apNode = nodeToTurnOn;  //a: This is the node where the AP wave will now start moving away from.
			muscle[muscleNumber].isOn = true; //b: Set to on.
			muscle[muscleNumber].timer = 0.0; //c: Set timer.
		}
	}
}


/*
 This CUDA function first moves the nodes then checks to see if the node is a beat node, if it is, it updates its time 
 and if its time is past the beat period it sends out a signal then zeros out its timer to start a new period.
 
 We also add some drag to the system to remove energy buildup.
*/
__global__ void updateNodes(nodeAttributesStructure *node, int numberOfNodes, int musclesPerNode, muscleAttributesStructure *muscle, float dt, float time)
{
	int i = threadIdx.x + blockDim.x*blockIdx.x;
	
	if(i < numberOfNodes)
	{
		if(!node[i].isAblated) // If node is not ablated do some work on it.
		{
		
			if(node[i].isBeatNode)
			{
				if(node[i].beatPeriod < node[i].beatTimer) // If the time is past its period set it to fire and reset it internal clock.
				{	
					node[i].isFiring = true;		
					node[i].beatTimer = 0.0; 
				}
				else
				{
					node[i].beatTimer += dt;
				}
			}
			
			// Turning on the muscle to any node that is ready to fire. Then setting fire to false so it will not fire again until it is ready.
			if(node[i].isFiring)
			{
				turnOnNodeMusclesGPU(i, numberOfNodes, musclesPerNode, muscle, node);
				node[i].isFiring = false;
			}
		}
	}	
}

/*
 This function triggers the next node when its signal reaches the end of the muscle.
 Then it colors the muscle depending on where the muscle is in its cycle.

 If a muscle reaches the end of its cycle it is turned off, its timer is set to zero,
 and its transmittion direction set to undetermined by setting apNode to -1. (do you mean transition or transmission-kyla ? Second this -Mason)
*/
__global__ void updateMuscles(muscleAttributesStructure *muscle, nodeAttributesStructure *node, int numberOfMuscles, int numberOfNodes, float dt, float4 readyColor, float4 depolarizingColor, float4 repolarizingColor, float4 relativeRepolarizingColor)
{
	int i = threadIdx.x + blockDim.x*blockIdx.x;
	int nodeId;
	
	if(i < numberOfMuscles)
	{
		if(muscle[i].isOn && muscle[i].isEnabled)
		{
			// Turning on the next node when the conduction front reaches it. This is at a certain floating point time this is why we used the +-dt
			// You can't just turn it on when the timer is greater than the conductionDuration because the timer is not reset here
			// and this would make this call happen every time step past conductionDuration until it was reset.
			if((muscle[i].conductionDuration - dt < muscle[i].timer) && (muscle[i].timer < muscle[i].conductionDuration + dt))
			{
				// Making the AP wave move forward through the muscle.
				if(muscle[i].apNode == muscle[i].nodeA)
				{
					nodeId = muscle[i].nodeB;
				}
				else
				{
					nodeId = muscle[i].nodeA;
				}
				
				if(!node[nodeId].isBeatNode)
				{
					node[nodeId].isFiring = true;
				}
				else
				{
					// If you want to do something with a beat node when it is hit by a signal, 
					// like reset its internal clock, do it here.
					// Currently we are simply ignoring the signal.
				}
			}
		
			float refractoryPeriod = muscle[i].refractoryPeriod;
			float absoluteRefractoryPeriod = refractoryPeriod*muscle[i].absoluteRefractoryPeriodFraction;
			//float relativeRefractoryPeriod = refractoryPeriod - absoluteRefractoryPeriod;
			
			if(muscle[i].timer < 0.5*refractoryPeriod)
			{
				// Set color and update time.
				muscle[i].color.x = depolarizingColor.x; 
				muscle[i].color.y = depolarizingColor.y;
				muscle[i].color.z = depolarizingColor.z;
				muscle[i].timer += dt;
			}
			else if(muscle[i].timer < absoluteRefractoryPeriod)
			{ 
				// Set color and update time.
				muscle[i].color.x = repolarizingColor.x;
				muscle[i].color.y = repolarizingColor.y;
				muscle[i].color.z = repolarizingColor.z;
				muscle[i].timer += dt;
			}
			else if(muscle[i].timer < refractoryPeriod)
			{ 
				// If you want to do something different in the relative refractory period do it here.
				// Set color and update time.
				muscle[i].color.x = relativeRepolarizingColor.x;
				muscle[i].color.y = relativeRepolarizingColor.y;
				muscle[i].color.z = relativeRepolarizingColor.z;
				muscle[i].timer += dt;
			}
			else
			{
				// Set color and turning the muscle off, reset timer, and apNode to unknown.
				muscle[i].color.x = readyColor.x;
				muscle[i].color.y = readyColor.y;
				muscle[i].color.z = readyColor.z;
				muscle[i].color.w = 1.0;
				
				muscle[i].isOn = false;
				muscle[i].timer = 0.0;
				muscle[i].apNode = -1;
			}	
		}
	}	
}

/*
 Checks to see if an error occurred in a CUDA call and returns the file name and line number where the error occurred.
*/
void cudaErrorCheck(const char *file, int line)
{
	cudaError_t  error;
	error = cudaGetLastError();

	if(error != cudaSuccess)
	{
		printf("\n CUDA ERROR: message = %s, File = %s, Line = %d\n", cudaGetErrorString(error), file, line);
		printf("\n The simulation has been terminated.\n\n");
		exit(0);
	}
}

/*

 Copies nodes and muscle attributes up to the GPU.
*/
void copyNodesMusclesToGPU()
{
    cudaMemcpyAsync(MuscleGPU, Muscle, NumberOfMuscles*sizeof(muscleAttributesStructure), cudaMemcpyHostToDevice, MemoryStream);
    cudaErrorCheck(__FILE__, __LINE__);
    
    cudaMemcpyAsync(NodeGPU, Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice, MemoryStream);
    cudaErrorCheck(__FILE__, __LINE__);
    
    // Synchronize memory stream to ensure transfer is complete
    cudaStreamSynchronize(MemoryStream);
}

/*

 * Copies nodes and muscle attributes down from the GPU.
 */
void copyNodesMusclesFromGPU()
{
    cudaMemcpyAsync(Muscle, MuscleGPU, NumberOfMuscles*sizeof(muscleAttributesStructure), cudaMemcpyDeviceToHost, MemoryStream);
    cudaErrorCheck(__FILE__, __LINE__);
    
    cudaMemcpyAsync(Node, NodeGPU, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyDeviceToHost, MemoryStream);
    cudaErrorCheck(__FILE__, __LINE__);
    
    // Synchronize memory stream to ensure transfer is complete
    cudaStreamSynchronize(MemoryStream);
}

/*

 * Copies node attributes down from the GPU
 */
void copyNodesFromGPU()
{
    cudaMemcpyAsync(Node, NodeGPU, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyDeviceToHost, MemoryStream);
    cudaErrorCheck(__FILE__, __LINE__);

	// Synchronize memory stream to ensure transfer is complete
    cudaStreamSynchronize(MemoryStream);
}

/*

 * Copies node attributes up to the GPU

 */
void copyNodesToGPU()
{
    cudaMemcpyAsync(NodeGPU, Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice, MemoryStream);
    cudaErrorCheck(__FILE__, __LINE__);

	// Synchronize memory stream to ensure transfer is complete
    cudaStreamSynchronize(MemoryStream);
}

// Utility Functions ***********************************************************************

/*
 This function: 
 Finds the average radius of the LA which we will use as the radius of the LA.
*/
double findAverageRadiusOfLeftAtrium()
{
	if(NumberOfNodes == 0)
	{
		printf("\n There seems to be no nodes to find the average radius of.");
		printf("\n The simulation has been terminated to stop divition by zero.\n");
		exit(0);
	}
	double averageRadius = 0.0;
	for(int i = 0; i < NumberOfNodes; i++)
	{
		averageRadius += sqrt(Node[i].position.x*Node[i].position.x + Node[i].position.y*Node[i].position.y + Node[i].position.z*Node[i].position.z);
	}
	averageRadius /= (double)NumberOfNodes;
	printf("\n RadiusOfLeftAtrium = %f millimeters", averageRadius);
	printf("\n LA radius has been set.\n");
	return(averageRadius);
}

/*
 This code 
 1: Checks to see if the electrical signal goes through the muscle faster than the refractory period.
    If it does not a muscle could fire itself and the signal would just bounce back and forth in the muscle.
    If this is true we just kill the muscle and move on.
 2: The muscle's absolute refoctory period should be greater than half the refractory period and less than the refractory period. 
    If not something is wrong. Here we kill the muscle and move on.
    
 We left each if statement as a stand alone unit in case the user wants to perform a different act in a selected
 if statement. We could have set a flag and just killed the the muscle after all checks, but this gives move
 flexibility for future directions. 
*/
void checkMuscle(int muscleId)
{
	// 1:
	if(Muscle[muscleId].refractoryPeriod < Muscle[muscleId].conductionDuration)
	{
	 	printf("\n\n Refractory period is shorter than the contraction duration in muscle number %d", muscleId);
	 	printf("\n Muscle %d will be disabled. \n", muscleId);
	 	Muscle[muscleId].isEnabled = false;
	 	Muscle[muscleId].color.x = DeadColor.x;
		Muscle[muscleId].color.y = DeadColor.y;
		Muscle[muscleId].color.z = DeadColor.z;
		Muscle[muscleId].color.w = 1.0;
	} 
	// 2:
	if(Muscle[muscleId].absoluteRefractoryPeriodFraction < 0.5 || 1.0 < Muscle[muscleId].absoluteRefractoryPeriodFraction)
	{
		printf("\n\n The absolute refractory period for muscle %d is %f. Rethink your parameters.", muscleId, Muscle[muscleId].absoluteRefractoryPeriodFraction);
	 	printf("\n Muscle %d will be disabled. \n", muscleId);
	 	Muscle[muscleId].isEnabled = false;
	 	Muscle[muscleId].color.x = DeadColor.x;

		Muscle[muscleId].color.y = DeadColor.y;
		Muscle[muscleId].color.z = DeadColor.z;
		Muscle[muscleId].color.w = 1.0;
	}
}

/*
 This function: 
 1: Uses the Box-Muller method to create a standard normal random number from two uniform random numbers.
 2: Sets the standard deviation to what was input.
 3: Checks to see if the random number is between the desired numbers. If not throw it away and choose again.
*/
double croppedRandomNumber(double stddev, double left, double right)
{
	double temp1, temp2;
	double randomNumber;
	bool test = false;
			
	while(test == false)
	{
		// Getting two uniform random numbers in [0,1]
		temp1 = ((double) rand() / (RAND_MAX));
		temp2 = ((double) rand() / (RAND_MAX));
		
		// Using Box-Muller to get a standard normally distributed random number (mean = 0, stddev = 1)
		randomNumber = sqrt(-2.0 * log(temp1))*cos(2.0*PI*temp2);
		
		// Setting its Standard Deviation to the the desired value. 
		randomNumber *= stddev;
		
		// Chopping the random number between left and right.  
		if(randomNumber < left || right < randomNumber) test = false;
		else test = true;
	}
	return(randomNumber);	
}

/*
 This function:
 Simple finds the center of the object and returns it.
*/
float4 findCenterOfObject()
{
	float4 centerOfObject;
	
	centerOfObject.x = 0.0;
	centerOfObject.y = 0.0;
	centerOfObject.z = 0.0;
	centerOfObject.w = 0.0;
	for(int i = 0; i < NumberOfNodes; i++)
	{
		 centerOfObject.x += Node[i].position.x;
		 centerOfObject.y += Node[i].position.y;
		 centerOfObject.z += Node[i].position.z;
		 centerOfObject.w += 1.0;;
	}
	if(centerOfObject.w < 1.0)
	{
		printf("\n There seems to be no nodes.");
		printf("\n The simulation has been terminated to stop divition by zero.\n");
		exit(0);
	}
	else
	{
		centerOfObject.x /= centerOfObject.w;
		centerOfObject.y /= centerOfObject.w;
		centerOfObject.z /= centerOfObject.w;
	}
	return(centerOfObject);
}

/*
 This function: 
 Centers the LA bassed on it's center of mass and resets the center of view to (0, 0, 0).
 It is called periodically in a running simulation to center the LA, because the LA is not symmetrical 
 and will wander off over time.
*/
void centerObject()
{
	float4 centerOfObject = findCenterOfObject();
	for(int i = 0; i < NumberOfNodes; i++)
	{
		Node[i].position.x -= centerOfObject.x;
		Node[i].position.y -= centerOfObject.y;
		Node[i].position.z -= centerOfObject.z;
	}
	CenterOfSimulation.x = 0.0;
	CenterOfSimulation.y = 0.0;
	CenterOfSimulation.z = 0.0;
}

/*
 This function:
 Translates the LA by dx. dy, and dz.
 You could use glTranslatef and this would change your view but your x,y,z locations do not get ajdusted and where we put the 
 selection sphere when selecting nodes get all screwed up so we must move all the nodes not the view.
*/
void translateObject(float dx, float dy, float dz)
{
	for(int i = 0; i < NumberOfNodes; i++)
	{
		Node[i].position.x += dx;
		Node[i].position.y += dy;
		Node[i].position.z += dz;
	}
	
	CenterOfSimulation.x += dx;
	CenterOfSimulation.y += dy;
	CenterOfSimulation.z += dz;
}


/*
 This function:
 Rotates the LA around the x-axis.
*/
void rotateXAxis(float angle)
{
	float temp;
	for(int i = 0; i < NumberOfNodes; i++)
	{
		temp = cos(angle)*Node[i].position.y - sin(angle)*Node[i].position.z;
		Node[i].position.z  = sin(angle)*Node[i].position.y + cos(angle)*Node[i].position.z;
		Node[i].position.y  = temp;
	}
	AngleOfSimulation.x += angle;
}

/*
 This function: 
 Rotates the LA around the y-axis.
*/
void rotateYAxis(float angle)
{
	float temp;
	for(int i = 0; i < NumberOfNodes; i++)
	{
		temp =  cos(-angle)*Node[i].position.x + sin(-angle)*Node[i].position.z;
		Node[i].position.z  = -sin(-angle)*Node[i].position.x + cos(-angle)*Node[i].position.z;
		Node[i].position.x  = temp;
	}
	AngleOfSimulation.y += angle;
}

/*
 This function: 
 Rotates the LA around the z-axis.
*/
void rotateZAxis(float angle)
{
	float temp;
	for(int i = 0; i < NumberOfNodes; i++)
	{
		temp = cos(angle)*Node[i].position.x - sin(angle)*Node[i].position.y;
		Node[i].position.y  = sin(angle)*Node[i].position.x + cos(angle)*Node[i].position.y;
		Node[i].position.x  = temp;
	}
	AngleOfSimulation.z += angle;
}

/*
 This function: 
 Returns a timestamp in M-D-Y-H.M.S format.
 This is use so each file that is created has a unique name. 
 Note: You cannot create more than one file in a second or you will over write the previous file.
*/
string getTimeStamp()
{
	// Want to get a time stamp string representing current date/time, so we have a
	// unique name for each video/screenshot taken.
	time_t t = time(0); 
	struct tm * now = localtime( & t );
	int month = now->tm_mon + 1, day = now->tm_mday, year = now->tm_year, 
				curTimeHour = now->tm_hour, curTimeMin = now->tm_min, curTimeSec = now->tm_sec;

	stringstream smonth, sday, syear, stimeHour, stimeMin, stimeSec;

	smonth << month;
	sday << day;
	syear << (year + 1900); // The computer starts counting from the year 1900, so 1900 is year 0. So we fix that.
	stimeHour << curTimeHour;
	stimeMin << curTimeMin;
	stimeSec << curTimeSec;
	string timeStamp;

	if (curTimeMin <= 9)
	{
		timeStamp = smonth.str() + "-" + sday.str() + "-" + syear.str() + '_' + stimeHour.str() + ".0" + stimeMin.str() + 
					"." + stimeSec.str();
	}
	else
	{		
		timeStamp = smonth.str() + "-" + sday.str() + '-' + syear.str() + "_" + stimeHour.str() + "." + stimeMin.str() +
					"." + stimeSec.str();
	}

	return timeStamp;
}

