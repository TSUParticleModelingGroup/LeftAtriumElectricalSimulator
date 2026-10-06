// Local include files
#include "./header.h"
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
	setSimulationRunDefaults();
	
	// Create a new run input a previous run file.
	if(NodesMusclesFileOrPreviousRunsFile == false)
	{
		createNewRun();
	}
	else if(NodesMusclesFileOrPreviousRunsFile == true)
	{
		uploadPreviousRun();
	}
	else
	{
		printf("\n\n Bad NodesMusclesFileOrPreviousRunsFile type %d.", NodesMusclesFileOrPreviousRunsFile);
		printf("\n The simulation has been terminated.\n\n");
		exit(0);
	}
	RadiusOfLeftAtrium = findAverageRadiusOfLeftAtrium();
	
	// Setting parameters that are not initially read from the node and muscle binary or previous run file.
	setRemainingParameters();
	
	setupCudaEnvironment();
	// Sending all the info that we have just created to the GPU so it can start crunching numbers.
	copyNodesMusclesToGPU();
	
	printf("\n\n Have a good simulation.\n\n");
	
	//generalSimulationSetup();

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
	glfwSetFramebufferSizeCallback(Window, reshapeCallback);  //sets the callback for the window resizing
	glfwSetCursorPosCallback(Window, mousePassiveMotionCallback); //sets the callback for the cursor position
	glfwSetMouseButtonCallback(Window, myMouseCallback); //sets the callback for the mouse clicks
	glfwSetScrollCallback(Window, scrollWheelCallback); //sets the callback for the mouse wheel
	glfwSetKeyCallback(Window, KeyPressedCallback); //sets the callback for the keyboard
	
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
	if(SimulationSwitch.ViewFlag == 0) // Orthogonal view
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
	//drawPicture();
	//glfwSwapBuffers(Window);
	// Main loop
	while (!glfwWindowShouldClose(Window))
	{
		glfwPollEvents();

		//keyHeld(Window); // Handle key hold events BMW

		// Start ImGui frame
		ImGui_ImplOpenGL3_NewFrame();
		ImGui_ImplGlfw_NewFrame();

		ImGui::NewFrame();
		
		// Update physics --multiple steps per frame for performance
		if (!SimulationSwitch.isPaused) 
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
	strcpy(fileName, "./NodesMuscles/");
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

	// Read global counts and pulse node
	fread(&NumberOfNodes, sizeof(int), 1, inFile);
	fread(&NumberOfMuscles, sizeof(int), 1, inFile);
	fread(&PulsePointNode, sizeof(int), 1, inFile);

	printf("\n NumberOfNodes = %d", NumberOfNodes);
	printf("\n NumberOfMuscles = %d", NumberOfMuscles);
	printf("\n PulsePointNode = %d", PulsePointNode);

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
 This function saves all the node and muscle values set in the run to a file. This file can then be used at a
 later date to start a run with the exact settings used at the time of capture.
 So if the user has spent a great deal of time setting up a scenario, they can save the scenario and use it again later.
 We use it to create scenarios that have arrhythmias preprogrammed into them and have members from a class we are
 presenting to come up and see if they can use the ablation tool to eliminate the arythmia.
*/
void saveRun()
{
	// Copying the latest node and muscle information down from the GPU.
	cudaMemcpy( Node, NodeGPU, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyDeviceToHost);
	cudaErrorCheck(__FILE__, __LINE__);
	cudaMemcpy( Muscle, MuscleGPU, NumberOfMuscles*sizeof(muscleAttributesStructure), cudaMemcpyDeviceToHost);
	cudaErrorCheck(__FILE__, __LINE__);
	
	// Moving into the file that contains previuos run files.
	chdir("./PreviousRunsFile");
	
	// Creating an output directory name to store run settings infomation in. It is unique down to the second  
	// to keep the user from overwriting files (You just cannot save more than one file a second).
	string timeStamp = "Run_" + getTimeStamp();
	const char *directoryName = timeStamp.c_str();
	
	// Creating the diretory to hold the run settings.
	if(mkdir(directoryName, 0777) == 0)
	{
		printf("\n Directory '%s' created successfully.\n", directoryName);
	}
	else
	{
		printf("\n Error creating directory '%s'.\n", directoryName);
	}
	
	// Moving into the directory
	chdir(directoryName);
	
	// Copying all the nodes and muscle (with their properties) into this folder in the file named run.
	FILE *runFile;
	
  	runFile = fopen("run", "wb");
	
	// Saving this to check if it is changed in an updated program and flag it if it has.
	int linksPerNode = MUSCLES_PER_NODE;
	fwrite(&linksPerNode, sizeof(int), 1, runFile);
	
	// Saving run values so the program will look exactly like it did when the run ended.
	fwrite(&RunTime, sizeof(double), 1, runFile);
	fwrite(&RefractoryPeriodAdjustmentMultiplier, sizeof(float), 1, runFile);
	fwrite(&MuscleConductionVelocityAdjustmentMultiplier, sizeof(float), 1, runFile);
	fwrite(&CenterOfSimulation, sizeof(float4), 1, runFile);
	fwrite(&AngleOfSimulation, sizeof(float4), 1, runFile);
	fwrite(&PulsePointNode, sizeof(int), 1, runFile);
	fwrite(&RadiusOfLeftAtrium, sizeof(double), 1, runFile);
	
	// Saving the switch value so the simulation will start exactly as it ended.
	fwrite(&SimulationSwitch, sizeof(SimulationSwitch), 1, runFile);
  	
  	// Saving the nodes.
	fwrite(&NumberOfNodes, sizeof(int), 1, runFile);
	fwrite(Node, sizeof(nodeAttributesStructure), NumberOfNodes, runFile);
	
	// Saving the muscles.
	fwrite(&NumberOfMuscles, sizeof(int), 1, runFile);
	fwrite(Muscle, sizeof(muscleAttributesStructure), NumberOfMuscles, runFile);
        
	fclose(runFile);
	
	//Copying the simulationSetup files into this directory so you will know how it was initally setup.
	FILE *fileIn;
	FILE *fileOut;
	long sizeOfFile;
  	char *buffer;

	//BASIC sim setup file
	fileIn = fopen("../../BasicSimulationSetup", "rb");

	if(fileIn == NULL)
	{
		printf("\n\n The basic simulationSetup file does not exist.");
		printf("\n The simulation has been terminated.\n\n");
		exit(0);
	}

	// Finding the size of the BasicSimulationSetup file.
	fseek (fileIn , 0 , SEEK_END);
  	sizeOfFile = ftell(fileIn);
  	rewind (fileIn);
  	
  	// Creating a buffer to hold the BasicSimulationSetup file.
  	buffer = (char*)malloc(sizeof(char)*sizeOfFile);
  	fread (buffer, 1, sizeOfFile, fileIn);
	fileOut = fopen("BasicSimulationSetup", "wb");
	fwrite (buffer, 1, sizeOfFile, fileOut);
	fclose(fileIn);
	fclose(fileOut);
	free(buffer);

	//INTERMEDIATE sim setup file
	fileIn = fopen("../../IntermediateSimulationSetup", "rb");

	if(fileIn == NULL)
	{
		printf("\n\n The intermediate simulationSetup file does not exist.");
		printf("\n The simulation has been terminated.\n\n");
		exit(0);
	}

	// Finding the size of the IntermediateSimulationSetup file.
	fseek (fileIn , 0 , SEEK_END);
  	sizeOfFile = ftell(fileIn);
  	rewind (fileIn);
  	
  	// Creating a buffer to hold the simulationSetup file.
  	buffer = (char*)malloc(sizeof(char)*sizeOfFile);
  	fread (buffer, 1, sizeOfFile, fileIn);
	fileOut = fopen("IntermediateSimulationSetup", "wb");
	fwrite (buffer, 1, sizeOfFile, fileOut);
	fclose(fileIn);
	fclose(fileOut);
	free(buffer);

	// Making a readMe file to put any infomation about why you are saving this run.
	system("gedit readMe");
	
	// Moving back to the SVT directory.
	chdir("../");
}

/*
 This function loads all the node and muscle attributes from a previous run file that was saved.
*/
void uploadPreviousRun()
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
	
	// Checking to see if linksPerNode has changed.
	int linksPerNode;
	fread(&linksPerNode, sizeof(int), 1, inFile);
        if(linksPerNode != MUSCLES_PER_NODE)
        {
              printf("\n\n The number Of muscle per node do not match.");
              printf("\n You will have to set the #define MUSCLES_PER_NODE");
              printf("\n to %d in header.h then recompile the code.", linksPerNode);
              printf("\n The simulation has been terminated.\n\n");
              exit(0);

        }
        
        // Reading run values so the program will look exactly like it did when the run ended.
        fread(&RunTime, sizeof(double), 1, inFile);
	fread(&RefractoryPeriodAdjustmentMultiplier, sizeof(float), 1, inFile);
	fread(&MuscleConductionVelocityAdjustmentMultiplier, sizeof(float), 1, inFile);
	fread(&CenterOfSimulation, sizeof(float4), 1, inFile);
	fread(&AngleOfSimulation, sizeof(float4), 1, inFile);
	fread(&PulsePointNode, sizeof(int), 1, inFile);
	fread(&RadiusOfLeftAtrium, sizeof(double), 1, inFile);
	
	// Reading the switch value so the simulation will start exactly as it ended.
	fread(&SimulationSwitch, sizeof(SimulationSwitch), 1, inFile);
  	
  	// Reading in the nodes and allocating space for them on the CPU and GPU.
        fread(&NumberOfNodes, sizeof(int), 1, inFile);
        printf("\n NumberOfNodes = %d.\n", NumberOfNodes);
        cudaHostAlloc(&Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaHostAllocDefault); // Making page locked memory on the CPU.
        cudaErrorCheck(__FILE__, __LINE__);
        cudaMalloc((void**)&NodeGPU, NumberOfNodes*sizeof(nodeAttributesStructure));
        cudaErrorCheck(__FILE__, __LINE__);
        fread(Node, sizeof(nodeAttributesStructure), NumberOfNodes, inFile);
        
	// Reading in the muscles and allocating space for them on the CPU and GPU.
        fread(&NumberOfMuscles, sizeof(int), 1, inFile);
        printf("\n NumberOfMuscles = %d.\n", NumberOfMuscles);
        cudaHostAlloc(&Muscle, NumberOfMuscles*sizeof(muscleAttributesStructure), cudaHostAllocDefault); // Making page locked memory on the CPU.
        cudaErrorCheck(__FILE__, __LINE__);
        cudaMalloc((void**)&MuscleGPU, NumberOfMuscles*sizeof(muscleAttributesStructure));
        cudaErrorCheck(__FILE__, __LINE__);
        fread(Muscle, sizeof(muscleAttributesStructure), NumberOfMuscles, inFile);
        
	fclose(inFile);
	
	printf("\n Previous run file: %s has been readin.\n", fileName);	
}

		
// Setup Functions *********************************************************************** 
/*
 This function:
 Sets the simulation's default run settings. Most of these will get over written if you run an previuos run but they are all
 set here for a new run and for safety if an existing file read did not set something.
*/
void setSimulationRunDefaults()
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

	SimulationSwitch.isPaused = true;
	SimulationSwitch.isInAblateMode = false;
	SimulationSwitch.isInEctopicBeatMode = false;
	SimulationSwitch.isInEctopicEventMode = false;
	SimulationSwitch.isInAdjustMuscleAreaMode = false;
	SimulationSwitch.isInAdjustMuscleLineMode = false;
	SimulationSwitch.isInFindNodeMode = false;
	SimulationSwitch.isInMouseFunctionMode = false;
	SimulationSwitch.isRecording = false;
	SimulationSwitch.ViewFlag = 1;
	SimulationSwitch.DrawNodesFlag = 0;
	SimulationSwitch.DrawFrontHalfFlag = 0;
	SimulationSwitch.ShowMuscleTypesFlag = false;
	SimulationSwitch.nodesFound = false;
	SimulationSwitch.guiCollapsed = false;
}

/*
 This function:
 Bla Bla BMW
*/
void createNewRun()
{
	// Seeding the random number generator.
	time_t t;
	srand((unsigned) time(&t));
	
	readNodesAndMusclesFromBinaryFile();
	setRemainingNodeAndMuscleAttributes();
	for(int i = 0; i < NumberOfMuscles; i++)
	{	
		checkMuscle(i);
	}
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
 1: Setting the pulse point node.
 2: Here we set the base muscle attributes. 
    a: Setting the muscles conduction velocity. 
    b: Setting the muscles conduction duration (How long it takes for a signal to travel across the muscle).
    c: Setting the muscle's refractory period.
    d: Setting the muscle's absolute refractory period.
 3: Setting all the node and muscle atributes based on type. 
*/
void setRemainingNodeAndMuscleAttributes()
{	
	// 1: This is the pulse point node that generates the beat.
	Node[PulsePointNode].isBeatNode = true;
	Node[PulsePointNode].beatPeriod = BeatPeriod;
	Node[PulsePointNode].beatTimer = BeatPeriod; // Set the time to BeatPeriod so it will kickoff a beat as soon as it starts.
	
	// 2:
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
	
	// 3:
	for(int i = 0; i < NumberOfNodes; i++)
	{
		if(Node[i].type == TypeBachmannBundle)
		{
			Node[i].isDrawNode = true;
		}
		else if(Node[i].type == TypePulmonaryVeins)
		{
			Node[i].isDrawNode = true;
		}
		else if(Node[i].type == TypeBackWall)
		{
			Node[i].isDrawNode = true;
		}
		else if(Node[i].type == TypeMitralValve)
		{
			Node[i].isDrawNode = true;
		}
		else if(Node[i].type == TypeAppendage)
		{
			Node[i].isDrawNode = true;
		}
		else if(Node[i].type == TypeStandardLA)
		{
			Node[i].isDrawNode = true;
		}
		else if(Node[i].type == TypeScarTissue)
		{
			Node[i].isAblated = true;
			Node[i].isDrawNode = true;
		}
		else if(Node[i].type == TypeExtraTissue)
		{
			Node[i].isAblated = true;
			Node[i].isDrawNode = true;
		}
		else
		{
			printf("\n\n Unknown tissue type.");
			printf("\n The simulation has been terminated.\n\n");
			exit(0);
		}
	}
	
	for(int i = 0; i < NumberOfMuscles; i++)
	{
		if(Muscle[i].type == TypeBachmannBundle)
		{
			Muscle[i].conductionDuration /= BachmannsBundleMultiplier;
		}
		else if(Muscle[i].type == TypePulmonaryVeins)
		{
			
		}
		else if(Muscle[i].type == TypeBackWall)
		{
			//
		}
		else if(Muscle[i].type == TypeMitralValve)
		{
			//
		}
		else if(Muscle[i].type == TypeAppendage)
		{
			//
		}
		else if(Muscle[i].type == TypeStandardLA)
		{
			//
		}
		else if(Muscle[i].type == TypeScarTissue)
		{
			//
		}
		else if(Muscle[i].type == TypeExtraTissue)
		{
			//
		}
		else
		{
			printf("\n\n Unknown tissue type.");
			printf("\n The simulation has been terminated.\n\n");
			exit(0);
		}
	}
	
	for(int i = 0; i < NumberOfMuscles; i++)
	{
		if(Muscle[i].type == TypeAppendage)
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

// Callback Functions ***********************************************************************

/*
 OpenGL callback when the window is reshaped.
*/
void reshapeCallback(GLFWwindow* window, int width, int height)
{
	// Update the window size variables for capture and mouse math
	XWindowSize = width;
	YWindowSize = height;

	// if we are recording we do not want to change the viewport or projection
	//otherwise the movie will be messed up
	if (SimulationSwitch.isRecording) return;

	// if not recording, set the viewport to match the new window size
	glViewport(0, 0, width, height); // Set the viewport size to match the window size

	//calculate the image aspect ratio
	float aspect = (float)width/(float)height;

	//set the projection matrix -- this is basically the camera
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();

	//now we need to maintain the same aspect ratio for both orthogonal and frustum view
	if(SimulationSwitch.ViewFlag == 0) // Orthogonal view
	{
		glOrtho(-aspect, aspect, -1.0, 1.0, -1.0, 1.0); // Orthogonal projection
	}
	else // Frustum view
	{
		glFrustum(-aspect, aspect, -1.0, 1.0, Near, Far); // Frustum projection
	}

	glMatrixMode(GL_MODELVIEW);
}

/*
 This function directs the action that needs to be taken if a user hits a key on the key board.
 The terminal screen lists out all the keys and what they will do.
*/
void KeyPressedCallback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
	float dAngle = 0.01;
	float dx,dy,dz;
	dx = dy = dz = 0.01*RadiusOfLeftAtrium;
	
	// See if GUI wants this event (Prevents keys from being registered when doing things like typing in a text box)
	ImGuiIO& io = ImGui::GetIO();
	if (io.WantCaptureKeyboard) return;

	// Tab always toggles GUI mode <-> mouse mode, even when GUI currently has focus.
	if(key == GLFW_KEY_TAB && action == GLFW_PRESS)
	{
		if (SimulationSwitch.isInMouseFunctionMode == true)
		{
			// Switch to GUI mode: collapse mouse mode, expand GUI
			SimulationSwitch.isInMouseFunctionMode = false;
			SimulationSwitch.guiCollapsed = false;
			glfwSetInputMode(Window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
		} 
		else 
		{
			// Switch to mouse mode: collapse GUI, enable mouse mode
			SimulationSwitch.isInMouseFunctionMode = true;
			SimulationSwitch.guiCollapsed = true;
			glfwSetInputMode(Window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
			centerMouse(window, &MouseX, &MouseY, &MouseZ);
		}
		return;
	}

	// X-axis Translations and Rotations
        if(key == GLFW_KEY_X && (action == GLFW_PRESS || action == GLFW_REPEAT))
        {
        	if((mods & GLFW_MOD_CONTROL) && (mods & GLFW_MOD_SHIFT)) rotateXAxis(-dAngle);
		else if(mods == GLFW_MOD_SHIFT) translateObject(dx, 0.0, 0.0);
		else if(mods == GLFW_MOD_CONTROL) rotateXAxis(dAngle);
		else translateObject(-dx, 0.0, 0.0);
        }
        
        // Y-axis Translations and Rotations
        if(key == GLFW_KEY_Y && (action == GLFW_PRESS || action == GLFW_REPEAT))
        {
        	if((mods & GLFW_MOD_CONTROL) && (mods & GLFW_MOD_SHIFT)) rotateYAxis(dAngle);
		else if(mods == GLFW_MOD_SHIFT) translateObject(0.0, dy, 0.0);
		else if(mods == GLFW_MOD_CONTROL) rotateYAxis(-dAngle);
		else translateObject(0.0, -dy, 0.0);
        }
        
        // Z-axis Translations and Rotations
        if(key == GLFW_KEY_Z && (action == GLFW_PRESS || action == GLFW_REPEAT))
        {
        	if((mods & GLFW_MOD_CONTROL) && (mods & GLFW_MOD_SHIFT)) rotateZAxis(-dAngle);
		else if(mods == GLFW_MOD_SHIFT) translateObject(0.0, 0.0, dz);
		else if(mods == GLFW_MOD_CONTROL) rotateZAxis(dAngle);
		else translateObject(0.0, 0.0, -dz);
        }
        
        if(key == GLFW_KEY_ESCAPE && action == GLFW_PRESS)
	{
		glfwSetWindowShouldClose(window, GLFW_TRUE);
		return;
	}
	
	if(key == GLFW_KEY_R && action == GLFW_PRESS)
	{
		if(SimulationSwitch.isPaused) SimulationSwitch.isPaused = false;
		else SimulationSwitch.isPaused = true;
		return;
	}
	
	if(key == GLFW_KEY_M && action == GLFW_PRESS)
	{
		if(SimulationSwitch.isRecording) movieOff();
		else movieOn();
		return;
	}
	
	if(key == GLFW_KEY_S && action == GLFW_PRESS)
	{
		screenShot();
		return;
	}
}

/*
 This function:
 Is called when the mouse moves without any button pressed.
 x and y are the current mouse coordinates.
 x come in as (0, XWindowSize) and y comes in as (0, YWindowSize). 
 We translates them to MouseX (-1, 1) and MouseY (-1, 1) to corospond to the openGL window size.
 We then use MouseX and MouseY to determine where the mouse is in the simulation.
*/
void mousePassiveMotionCallback(GLFWwindow* window, double x, double y)
{
	// Get ImGui IO to check if mouse is over ImGui windows
    ImGuiIO& io = ImGui::GetIO();

	//Show cursor when highlighting over IMGUI elements
	if (SimulationSwitch.isInMouseFunctionMode)
	{
		//Uncomment this to have the cursor show when it hovers the GUI in mouse function mode
		if (io.WantCaptureMouse)
		{
			glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
			return; // If ImGui is capturing the mouse, do not process further
		}
		else
		{
			glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
		}
		
	}
	
	float sensitivityMultiplier = 1.2; // Sensitivity multiplier for mouse movement
	MouseX = ( 2.0*x/XWindowSize - 1.0)*RadiusOfLeftAtrium *sensitivityMultiplier;
	MouseY = (-2.0*y/YWindowSize + 1.0)*RadiusOfLeftAtrium *sensitivityMultiplier;
}

/* 
 This function:
 Is called when a mouse scroll whell action is detected.
*/
void scrollWheelCallback(GLFWwindow* window, double xoffset, double yoffset)
{
	bool ctrlHeld = (glfwGetKey(window, GLFW_KEY_LEFT_CONTROL) == GLFW_PRESS || glfwGetKey(window, GLFW_KEY_RIGHT_CONTROL) == GLFW_PRESS);
    
	if(ctrlHeld)
	{
		// Ctrl+Scroll functionality - adjust selector size
		if(yoffset > 0) // Scroll up - increase selector size
		{
			HitMultiplier += 0.025;
			if(HitMultiplier > 0.5) HitMultiplier = 0.5;
		}
		else if(yoffset < 0) // Scroll down - decrease selector size
		{
			HitMultiplier -= 0.01;
			if(HitMultiplier < 0.01) HitMultiplier = 0.01;
		}
	}
	else
	{
		// Normal Scroll functionality
		if(yoffset > 0) // Scroll up
		{
			MouseZ -= ScrollSpeed;
		}
		else if(yoffset < 0) // Scroll down
		{
			MouseZ += ScrollSpeed;
		}
	}
	// printf("MouseZ = %f\n", MouseZ);
	drawPicture();
}

/*
 This function:
 Does an action based on the mode the viewer is in and which mouse button the user pressed.
*/
void myMouseCallback(GLFWwindow* window, int button, int action, int mods)
{	

	//Add this if we want the GUI to only accept GUI handling until you ckick off of it
    // Get ImGui IO to check if it's capturing input
    ImGuiIO& io = ImGui::GetIO();
    
    // If ImGui is handling this mouse event, return
    if (io.WantCaptureMouse) return;
	
	float d, dx, dy, dz;
	float hit;
	int muscleId;
	
	if(action == GLFW_PRESS)
	{
		// Check for Ctrl+Click to center mouse
		if(mods & GLFW_MOD_CONTROL)
		{
			centerMouse(window, &MouseX, &MouseY, &MouseZ);
		}
		
		// Only allow mode actions when in mouse function mode
		if(!SimulationSwitch.isInMouseFunctionMode)
		{
			return;
		}

		copyNodesMusclesFromGPU();
		
		hit = HitMultiplier*RadiusOfLeftAtrium;
		
		if(button == GLFW_MOUSE_BUTTON_LEFT)
		{	
			if(SimulationSwitch.isInAdjustMuscleLineMode)
			{
				// Finding the two closest nodes to the mouse.
				int nodeId1 = -1;
				int nodeId2 = -1;
				int connectingMuscle = -1;
				int test = -1;
				float minDistance = 2.0*RadiusOfLeftAtrium;
				for(int i = 0; i < NumberOfNodes; i++)
				{
					dx = MouseX - Node[i].position.x;
					dy = MouseY - Node[i].position.y;
					dz = MouseZ - Node[i].position.z;
					d = sqrt(dx*dx + dy*dy + dz*dz);
					if(d < minDistance)
					{
						minDistance = d;
						nodeId2 = nodeId1;
						nodeId1 = i;
					}
				}
				
				// If for some reason two nodes were not found. Not sure how this could
				// happen, but just to be safe we put a check in here.
				if(nodeId2 == -1)
				{
					printf("\n Two nodes were not found try again.\n");
					printf("\n MouseZ = %lf.\n", MouseZ);
				}
				// We got the two closest nodes to the mouse. Now see if there is a muscle that
				// connects these two nodes. If there is a connecting muscle, adjust it.
				else
				{
					if(!Node[nodeId1].isAblated)
					{
						Node[nodeId1].color.x = 1.0;
						Node[nodeId1].color.y = 0.0;
						Node[nodeId1].color.z = 1.0;
						Node[nodeId1].isDrawNode = true;
					}
					
					if(!Node[nodeId2].isAblated)
					{
						Node[nodeId2].color.x = 1.0;
						Node[nodeId2].color.y = 0.0;
						Node[nodeId2].color.z = 1.0;
						Node[nodeId2].isDrawNode = true;
					}
					
					for(int i = 0; i < MUSCLES_PER_NODE; i++) // Spinnning through muscles on node 1.
					{
						muscleId = Node[nodeId1].muscle[i]; 
						if(muscleId != -1)
						{
							for(int j = 0; j < MUSCLES_PER_NODE; j++) // Spinnning through muscles on node 2.
							{
								test = Node[nodeId2].muscle[j];
								if(muscleId == test) // Checking to see if we get a match.
								{
									connectingMuscle = muscleId;
								}
							}
						}
					}
					if(connectingMuscle == -1)
					{
						printf("\n No connecting muscle was found try again.\n");
					}
					else
					{
						muscleId = connectingMuscle;
						Muscle[muscleId].refractoryPeriod = BaseMuscleRefractoryPeriod*RefractoryPeriodAdjustmentMultiplier;
						Muscle[muscleId].conductionVelocity = BaseMuscleConductionVelocity*MuscleConductionVelocityAdjustmentMultiplier;
						Muscle[muscleId].conductionDuration = Muscle[muscleId].naturalLength/Muscle[muscleId].conductionVelocity;
						Muscle[muscleId].color.x = 1.0;
						Muscle[muscleId].color.y = 0.0;
						Muscle[muscleId].color.z = 1.0;
						Muscle[muscleId].color.w = 0.0;
						
						checkMuscle(muscleId);		
					}
				}
			}
			else if(SimulationSwitch.isInFindMuscleMode)
			{
				// Find the closest muscle to the mouse and identify it
				int closestMuscle = -1;
				float minDist = 1e9;
				for(int m = 0; m < NumberOfMuscles; m++)
				{
					int a = Muscle[m].nodeA;
					int b = Muscle[m].nodeB;
					float mx = 0.5f * (Node[a].position.x + Node[b].position.x);
					float my = 0.5f * (Node[a].position.y + Node[b].position.y);
					float mz = 0.5f * (Node[a].position.z + Node[b].position.z);
					float dx = MouseX - mx;
					float dy = MouseY - my;
					float dz = MouseZ - mz;
					float dist = sqrt(dx*dx + dy*dy + dz*dz);
					if(dist < minDist && dist < hit) // Only select if within hit radius
					{
						minDist = dist;
						closestMuscle = m;
					}
				}
				if(closestMuscle != -1)
				{
					identifyMuscleAtIndex(closestMuscle);
				}
				return;
			}
			else
			{
				for(int i = 0; i < NumberOfNodes; i++)
				{
					dx = MouseX - Node[i].position.x;
					dy = MouseY - Node[i].position.y;
					dz = MouseZ - Node[i].position.z;
					
					if(sqrt(dx*dx + dy*dy + dz*dz) < hit)
					{
						if(SimulationSwitch.isInAblateMode)
						{
							Node[i].isAblated = true;
							Node[i].isDrawNode = true;
							Node[i].color.x = 1.0;
							Node[i].color.y = 1.0;
							Node[i].color.z = 1.0;
						}
						
						if(SimulationSwitch.isInEctopicBeatMode)
						{
							SimulationSwitch.isPaused = true;
							// printf("\n Node number = %d", i);
							setEctopicBeat(i);
						}
						
						if(SimulationSwitch.isInAdjustMuscleAreaMode)
						{
							for(int j = 0; j < MUSCLES_PER_NODE; j++)
							{
								muscleId = Node[i].muscle[j];
								if(muscleId != -1)
								{
									// This sets the muscle to the base value then adjusts it. 
									Muscle[muscleId].refractoryPeriod = BaseMuscleRefractoryPeriod*RefractoryPeriodAdjustmentMultiplier;
									Muscle[muscleId].conductionVelocity = BaseMuscleConductionVelocity*MuscleConductionVelocityAdjustmentMultiplier;
									
									// This adjusts the muscle based on its current value.
									//Muscle[muscleId].refractoryPeriod *= RefractoryPeriodAdjustmentMultiplier;
									//Muscle[muscleId].conductionVelocity *= MuscleConductionVelocityAdjustmentMultiplier;
									
									Muscle[muscleId].conductionDuration = Muscle[muscleId].naturalLength/Muscle[muscleId].conductionVelocity;
									Muscle[muscleId].color.x = 1.0;
									Muscle[muscleId].color.y = 0.0;
									Muscle[muscleId].color.z = 1.0;
									Muscle[muscleId].color.w = 0.0;
									
									checkMuscle(muscleId);
								}
							}
							
							Node[i].isDrawNode = true;
							if(!Node[i].isAblated) // If it is not ablated color it.
							{
								Node[i].color.x = 0.8;
								Node[i].color.y = 0.3;
								Node[i].color.z = 1.0;
							}
						}
						
						if(SimulationSwitch.isInEctopicEventMode)
						{
							cudaMemcpy( Node, NodeGPU, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyDeviceToHost);
							cudaErrorCheck(__FILE__, __LINE__);
							
							Node[i].isFiring = true; // Setting the ith node to fire the next time in the next time step.

							//Create a pink point sprite at the node
							Node[i].color.x = 0.996;
							Node[i].color.y = 0.242;
							Node[i].color.z = 0.637;
							Node[i].isDrawNode = true;
							
							cudaMemcpy( NodeGPU, Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice );
							cudaErrorCheck(__FILE__, __LINE__);
							printf("\n Ectopic Event Node Number = %d, Time = %f\n", i, RunTime);
						}
						
						if(SimulationSwitch.isInFindNodeMode)
						{
							Node[i].isDrawNode = true;
							Node[i].color.x = 1.0;
							Node[i].color.y = 0.0;
							Node[i].color.z = 1.0;
							// printf("\n Node number = %d", i);
						}
					}
				}
			}
		}
		else if(button == GLFW_MOUSE_BUTTON_RIGHT) // Right Mouse button down
		{
			if(SimulationSwitch.isInAdjustMuscleLineMode)
			{
				// Finding the two closest nodes to the mouse.
				int nodeId1 = -1;
				int nodeId2 = -1;
				int connectingMuscle = -1;
				int test = -1;
				float minDistance = 2.0*RadiusOfLeftAtrium;
				for(int i = 0; i < NumberOfNodes; i++)
				{
					dx = MouseX - Node[i].position.x;
					dy = MouseY - Node[i].position.y;
					dz = MouseZ - Node[i].position.z;
					d = sqrt(dx*dx + dy*dy + dz*dz);
					if(d < minDistance)
					{
						minDistance = d;
						nodeId2 = nodeId1;
						nodeId1 = i;
					}
				}
				
				// If for some reason two nodes were not found. Not sure how this could
				// happen, but just to be safe we put a check in here.
				if(nodeId2 == -1)
				{
					printf("\n Two nodes were not found try again.\n");
					printf("\n MouseZ = %lf.\n", MouseZ);
				}
				// We got the two closest nodes to the mouse. Now see if there is a muscle that
				// connects these two nodes. If there is a connecting muscle, adjust it.
				else
				{
					if(!Node[nodeId1].isAblated)
					{
						Node[nodeId1].color.x = 0.0;
						Node[nodeId1].color.y = 1.0;
						Node[nodeId1].color.z = 0.0;
						Node[nodeId1].isDrawNode = false;
					}
					
					if(!Node[nodeId2].isAblated)
					{
						Node[nodeId2].color.x = 0.0;
						Node[nodeId2].color.y = 1.0;
						Node[nodeId2].color.z = 0.0;
						Node[nodeId2].isDrawNode = false;
					}
					
					for(int i = 0; i < MUSCLES_PER_NODE; i++) // Spinnning through muscles on node 1.
					{
						muscleId = Node[nodeId1].muscle[i]; 
						if(muscleId != -1)
						{
							for(int j = 0; j < MUSCLES_PER_NODE; j++) // Spinnning through muscles on node 2.
							{
								test = Node[nodeId2].muscle[j];
								if(muscleId == test) // Checking to see if we get a match.
								{
									connectingMuscle = muscleId;
								}
							}
						}
					}
					if(connectingMuscle == -1)
					{
						printf("\n No connecting muscle was found try again.\n");
					}
					else
					{
						muscleId = connectingMuscle;
						Muscle[muscleId].refractoryPeriod = BaseMuscleRefractoryPeriod;
						Muscle[muscleId].conductionVelocity = BaseMuscleConductionVelocity;
						Muscle[muscleId].conductionDuration = Muscle[muscleId].naturalLength/Muscle[muscleId].conductionVelocity;
						Muscle[muscleId].color.x = 0.0;
						Muscle[muscleId].color.y = 1.0;
						Muscle[muscleId].color.z = 0.0;
						Muscle[muscleId].color.w = 0.0;
						// Turning the muscle back on if it was disabled.
						Muscle[muscleId].isEnabled = true;
						
						checkMuscle(muscleId);		
					}
				}
			}
			else
			{
				for(int i = 0; i < NumberOfNodes; i++)
				{
					dx = MouseX - Node[i].position.x;
					dy = MouseY - Node[i].position.y;
					dz = MouseZ - Node[i].position.z;
					if(sqrt(dx*dx + dy*dy + dz*dz) < hit)
					{
						if(SimulationSwitch.isInAblateMode)
						{
							Node[i].isAblated = false;
							Node[i].isDrawNode = false;
							Node[i].color.x = 0.0;
							Node[i].color.y = 1.0;
							Node[i].color.z = 0.0;
						}
						
						if(SimulationSwitch.isInAdjustMuscleAreaMode)
						{
							for(int j = 0; j < MUSCLES_PER_NODE; j++)
							{
								muscleId = Node[i].muscle[j];
								if(muscleId != -1)
								{
									Muscle[muscleId].refractoryPeriod = BaseMuscleRefractoryPeriod;
									Muscle[muscleId].conductionVelocity = BaseMuscleConductionVelocity;
									Muscle[muscleId].conductionDuration = Muscle[muscleId].naturalLength/Muscle[muscleId].conductionVelocity;
									Muscle[muscleId].color.x = 0.0;
									Muscle[muscleId].color.y = 1.0;
									Muscle[muscleId].color.z = 0.0;
									Muscle[muscleId].color.w = 0.0;
									
									// Turning the muscle back on if it was disabled.
									Muscle[muscleId].isEnabled = true;
									
									// Checking to see if the muscle needs to be killed.
									checkMuscle(muscleId);
								}
							}
							
							Node[i].isDrawNode = true;
							if(!Node[i].isAblated) // If it is not ablated color it.
							{
								Node[i].color.x = 0.0;
								Node[i].color.y = 1.0;
								Node[i].color.z = 0.0;
							}
						}

						//Reset ectopic trigger colors
						if(SimulationSwitch.isInEctopicEventMode)
						{
							Node[i].color.x = 0.0;
							Node[i].color.y = 1.0;
							Node[i].color.z = 0.0;
						}
					}
				}
			}
		}
		else if(button == GLFW_MOUSE_BUTTON_MIDDLE)
		{
			if(ScrollSpeedToggle == 0)
			{
				ScrollSpeedToggle = 1;
				ScrollSpeed = 1.0;
				// printf("\n speed = %f\n", ScrollSpeed);
			}
			else
			{
				ScrollSpeedToggle = 0;
				ScrollSpeed = 0.1;
				// printf("\n speed = %f\n", ScrollSpeed);
			}
			
		}
		drawPicture();
		copyNodesMusclesToGPU();
		//printf("\nSNx = %f SNy = %f SNz = %f\n", NodePosition[0].x, NodePosition[0].y, NodePosition[0].z);
	}
}











// Mouse action functions *******************************************************************

/*
 Turns off all the user interactions.
*/
void mouseFunctionsOff()
{
	//SimulationSwitch.isPaused = true;
	SimulationSwitch.isInAblateMode = false;
	SimulationSwitch.isInEctopicBeatMode = false;
	SimulationSwitch.isInEctopicEventMode = false;
	SimulationSwitch.isInAdjustMuscleAreaMode = false;
	SimulationSwitch.isInAdjustMuscleLineMode = false;
	SimulationSwitch.isInFindNodeMode = false;
	SimulationSwitch.isInFindMuscleMode = false;
	SimulationSwitch.isInMouseFunctionMode = false;
	SimulationSwitch.guiCollapsed = false;
	glfwSetInputMode(Window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
	drawPicture();
}

/*
 Puts the user in ablate mode.
*/
void mouseAblateMode()
{
	mouseFunctionsOff();
	SimulationSwitch.isPaused = true;
	SimulationSwitch.isInAblateMode = true;
	drawPicture();
}

/*
 Puts the user in ectopic beat mode.
*/
void mouseEctopicBeatMode()
{
	mouseFunctionsOff();
	SimulationSwitch.isPaused = true;
	SimulationSwitch.isInEctopicBeatMode = true;
	drawPicture();
}

/*
 Puts the user in ectopic event mode.
*/
void mouseEctopicEventMode()
{
	mouseFunctionsOff();
	SimulationSwitch.isPaused = true;
	SimulationSwitch.isInEctopicEventMode = true;
	drawPicture();
}

/*
 Puts the user in area muscle adjustment mode.
*/
void mouseAdjustMusclesAreaModeMultiplier()
{
	mouseFunctionsOff();
	SimulationSwitch.isPaused = true;
	SimulationSwitch.isInAdjustMuscleAreaMode = true;
	drawPicture();
}

/*
 Puts the user in line muscle adjustment mode.
*/
void mouseAdjustMusclesLineModeMultiplier()
{
	mouseFunctionsOff();
	SimulationSwitch.isPaused = true;
	SimulationSwitch.isInAdjustMuscleLineMode = true;
	drawPicture();
}

/*
 Puts the user in identify node mode.

*/
void mouseIdentifyNodeMode()
{
	mouseFunctionsOff();
	SimulationSwitch.isPaused = true;
	SimulationSwitch.isInFindNodeMode = true;
	drawPicture();
}

void mouseIdentifyMuscleMode()
{
	mouseFunctionsOff();
	SimulationSwitch.isPaused = true;
	SimulationSwitch.isInFindMuscleMode = true;
	//glfwSetInputMode(Window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
	drawPicture();
}

// Helper for Identify Muscle mode: only one muscle can be blue at a time
void identifyMuscleAtIndex(int muscleIndex)
{
	//set the selected muscle to blue (marking it as an identified muscle)
	Muscle[muscleIndex].color.x = 0.0f;
	Muscle[muscleIndex].color.y = 0.0f;
	Muscle[muscleIndex].color.z = 0.7f;
	copyNodesMusclesToGPU();
	drawPicture();
}

/*
 This function sets up a node (nodeId) to be an ectopic beat node.
*/
void setEctopicBeat(int nodeId)
{
	Node[nodeId].isBeatNode = true;
	
	if(!Node[nodeId].isAblated)
	{
		Node[nodeId].isDrawNode = true;
		Node[nodeId].color.x = 1.0;
		Node[nodeId].color.y = 1.0;
		Node[nodeId].color.z = 0.0;
	}
	drawPicture();
	
	// Set default values - these used to come from user input functions
	Node[nodeId].beatPeriod = BeatPeriod; // Default to same as main beat
	Node[nodeId].beatTimer = 0; // Default to start immediately
	
	
	// We only let you set 1 ectopic beat at a time.
	SimulationSwitch.isInEctopicBeatMode = false;
}

// Movie and screenshot functions **********************************************************
/*
 This function:
 Sets the screen for different qualities used by both video and screenshots.
*/
static void getQualityPresetDimensions(int preset, int& targetWidth, int& targetHeight)
{
	switch (preset)
	{
		case 0:
			targetWidth = 1920;
			targetHeight = 1080;
			break;
		case 1:
			targetWidth = 2560;
			targetHeight = 1440;
			break;
		case 2:
			targetWidth = 3200;
			targetHeight = 1800;
			break;
		case 3:
			targetWidth = 3840;
			targetHeight = 2160;
			break;
		default:
			targetWidth = CaptureWidth;
			targetHeight = CaptureHeight;
			break;
	}
}

/*
 This function:
 Turns the movie capture on.
*/
void movieOn()
{
	string ts = getTimeStamp();
	ts.append(".mp4");

	char baseCommand[512]; // Command to run ffmpeg with the correct parameters for capturing a movie
	int targetWidth = 0;
	int targetHeight = 0;
	getQualityPresetDimensions(QualityPreset, targetWidth, targetHeight);

	// H.264 (yuv420p) prefers even dimensions, so pad the preset size by up to one pixel.
	int outW = targetWidth + (targetWidth % 2);
	int outH = targetHeight + (targetHeight % 2);
	int padX = (outW - targetWidth) / 2;
	int padY = (outH - targetHeight) / 2;

	const bool isScPreset = (QualityPreset == 3);
	if (isScPreset)
	{
		// SC uses stricter encoding settings for conference submission output.
		sprintf(baseCommand, "ffmpeg -loglevel error -f rawvideo -pix_fmt rgba -s %dx%d -r 60 -i - "
			"-c:v libx264 -pix_fmt yuv420p -profile:v high -level 4.2 -crf 10 -preset veryslow -tune film -threads 0 -movflags +faststart -y -vf \"scale=%d:%d,pad=%d:%d:%d:%d\" \"%s\"", 
			CaptureWidth, CaptureHeight, targetWidth, targetHeight, outW, outH, padX, padY, ts.c_str());
	}
	else
	{
		// Standard presets keep a lighter encode while still scaling to the selected size.
		sprintf(baseCommand, "ffmpeg -loglevel error -f rawvideo -pix_fmt rgba -s %dx%d -r 60 -i - "
			"-c:v libx264 -pix_fmt yuv420p -profile:v high -level 4.0 -crf 14 -preset slow -tune film -threads 0 -movflags +faststart -y -vf \"scale=%d:%d,pad=%d:%d:%d:%d\" \"%s\"", 
			CaptureWidth, CaptureHeight, targetWidth, targetHeight, outW, outH, padX, padY, ts.c_str());
	}

	MovieFile = popen(baseCommand, "w");
	Buffer = (unsigned char*)malloc(4 * CaptureWidth * CaptureHeight);

	SimulationSwitch.isRecording = true;
}

/*
 This function: 
 Turns the movie capture off.
*/
void movieOff()
{
	if(SimulationSwitch.isRecording) 
	{
		pclose(MovieFile);
	}
	free(Buffer);
	SimulationSwitch.isRecording = false;
}

/*
 This function: 
 Takes a screenshot of the simulation.
*/
void screenShot()
{	
	bool savedPauseState;
	FILE* ScreenShotFile;
	unsigned char* buffer; //unsigned char because we are using RGBA data, which is 4 bytes per pixel, 1 char = 1 byte

	char cmd[512];
	int targetWidth = 0;
	int targetHeight = 0;
	getQualityPresetDimensions(QualityPreset, targetWidth, targetHeight);

	string ts = getTimeStamp();
	// Reuse the same preset size for screenshots so the output matches the chosen quality.
	sprintf(cmd, "ffmpeg -loglevel error -f rawvideo -pix_fmt rgba -s %dx%d -i - -frames:v 1 -vf \"scale=%d:%d,vflip\" -c:v png \"%s.png\"", 
		CaptureWidth, CaptureHeight, targetWidth, targetHeight, ts.c_str());
	
	ScreenShotFile = popen(cmd, "w");
	buffer = (unsigned char*)malloc(4 * CaptureWidth * CaptureHeight);
	
	if(!SimulationSwitch.isPaused) //if the simulation is running
	{
		SimulationSwitch.isPaused = true; //pause the simulation
		savedPauseState = false; //save the pause state
	}
	else //if the simulation is already paused
	{
		savedPauseState = true; //save the pause state
	}
	
	for(int i =0; i < 1; i++)
	{
		drawPicture();
		glReadPixels(0, 0, CaptureWidth, CaptureHeight, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
		fwrite(buffer, 4 * CaptureWidth * CaptureHeight, 1, ScreenShotFile);
	}
	
	pclose(ScreenShotFile);
	free(buffer);
	printf("\nScreenshot Captured: \n");
	SimulationSwitch.isPaused = savedPauseState; //restore the pause state before we took the screenshot
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
	
	copyNodesFromGPU();
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
	copyNodesToGPU();
	CenterOfSimulation.x = 0.0;
	CenterOfSimulation.y = 0.0;
	CenterOfSimulation.z = 0.0;
}

/*
 This function: 
 Centers the mouse by moving it to (0, 0, Radius).
*/
int centerMouse(GLFWwindow* window, double* mx, double* my, double* mz)
{
	*mx = 0.0f;
	*my = 0.0f;
	*mz = RadiusOfLeftAtrium;
	// Move cursor to center of screen. If you don't as soon as you move the mouse the sphere will move to the cursor.
	glfwSetCursorPos(window, XWindowSize / 2.0, YWindowSize / 2.0); 
	return 1;
}

/*
 This function:
 Translates the LA by dx. dy, and dz.
 You could use glTranslatef and this would change your view but your x,y,z locations do not get ajdusted and where we put the 
 selection sphere when selecting nodes get all screwed up so we must move all the nodes not the view.
*/
void translateObject(float dx, float dy, float dz)
{
	copyNodesFromGPU();
	for(int i = 0; i < NumberOfNodes; i++)
	{
		Node[i].position.x += dx;
		Node[i].position.y += dy;
		Node[i].position.z += dz;
	}
	copyNodesToGPU();
	
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
	copyNodesFromGPU();
	for(int i = 0; i < NumberOfNodes; i++)
	{
		temp = cos(angle)*Node[i].position.y - sin(angle)*Node[i].position.z;
		Node[i].position.z  = sin(angle)*Node[i].position.y + cos(angle)*Node[i].position.z;
		Node[i].position.y  = temp;
	}
	copyNodesToGPU();
	AngleOfSimulation.x += angle;
}

/*
 This function: 
 Rotates the LA around the y-axis.
*/
void rotateYAxis(float angle)
{
	float temp;
	copyNodesFromGPU();
	for(int i = 0; i < NumberOfNodes; i++)
	{
		temp =  cos(-angle)*Node[i].position.x + sin(-angle)*Node[i].position.z;
		Node[i].position.z  = -sin(-angle)*Node[i].position.x + cos(-angle)*Node[i].position.z;
		Node[i].position.x  = temp;
	}
	copyNodesToGPU();
	AngleOfSimulation.y += angle;
}

/*
 This function: 
 Rotates the LA around the z-axis.
*/
void rotateZAxis(float angle)
{
	float temp;
	copyNodesFromGPU();
	for(int i = 0; i < NumberOfNodes; i++)
	{
		temp = cos(angle)*Node[i].position.x - sin(angle)*Node[i].position.y;
		Node[i].position.y  = sin(angle)*Node[i].position.x + cos(angle)*Node[i].position.y;
		Node[i].position.x  = temp;
	}
	copyNodesToGPU();
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


