/*
 This file contains all the callback functions and the functions they call to do their work.
 This file contains all the ways a user can interact (Mouse and Terminal) with a running simulation.
*/

// Map the shared preset selection to the export resolution used by both video and screenshots.
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
 OpenGL callback when the window is reshaped.
*/
void reshape(GLFWwindow* window, int width, int height)
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
	float aspect = (float)width / (float)height;

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
	//glLoadIdentity(); //don't need this because it resets the camera every time we reshape
}

int centerMouse(GLFWwindow* window, double* mx, double* my, double* mz)
{
	*mx = 0.0f;
	*my = 0.0f;
	*mz = 0.0f;
	glfwSetCursorPos(window, XWindowSize / 2.0, YWindowSize / 2.0); // Move cursor to center of screen
	return 1;
}

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
	
	//bool returnFlag = setMouseMuscleAttributes();
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
	
	//bool returnFlag = setMouseMuscleAttributes();
	
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

/*
 This function turns the movie capture on.
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
 This function turns the movie capture off.
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
 This function takes a screenshot of the simulation.
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
	cout << "Saved as " << ts << ".png" << endl;

	
	//system("ffmpeg -i output1.mp4 screenShot.jpeg");
	//system("rm output1.mp4");

	SimulationSwitch.isPaused = savedPauseState; //restore the pause state before we took the screenshot
	//ffmpeg -i output1.mp4 output_%03d.jpeg
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
	
	// Creating an output directory name to store run settings infomation in. It is unique down to the second to keep the user from 
	// overwriting files (You just cannot save more than one file a second).
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
	FILE *settingFile;
	
  	settingFile = fopen("run", "wb");
  	
	fwrite(&NumberOfNodes, sizeof(int), 1, settingFile);
	fwrite(Node, sizeof(nodeAttributesStructure), NumberOfNodes, settingFile);

	int linksPerNode = MUSCLES_PER_NODE;
	fwrite(&linksPerNode, sizeof(int), 1, settingFile);

	fwrite(&NumberOfMuscles, sizeof(int), 1, settingFile);
	fwrite(Muscle, sizeof(muscleAttributesStructure), NumberOfMuscles, settingFile);

	fwrite(&SimulationSwitch, sizeof(SimulationSwitch), 1, settingFile);

	fwrite(&PulsePointNode, sizeof(int), 1, settingFile);
	fwrite(&UpNode, sizeof(int), 1, settingFile);
	fwrite(&FrontNode, sizeof(int), 1, settingFile);

	fwrite(&ViewName, sizeof(char), 256, settingFile);

	fwrite(&RefractoryPeriodAdjustmentMultiplier, sizeof(float), 1, settingFile);
	fwrite(&MuscleConductionVelocityAdjustmentMultiplier, sizeof(float), 1, settingFile);

	fwrite(&RadiusOfLeftAtrium, sizeof(double), 1, settingFile);

	fwrite(&CenterOfSimulation, sizeof(float4), 1, settingFile);
	fwrite(&AngleOfSimulation, sizeof(float4), 1, settingFile);

	fwrite(&RunTime, sizeof(double), 1, settingFile);
        
	fclose(settingFile);
	
	//Copying the simulationSetup file into this directory so you will know how it was initally setup.
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

void saveState()
{
    // Copy latest data from GPU
    cudaMemcpy(Node, NodeGPU, NumberOfNodes * sizeof(nodeAttributesStructure), cudaMemcpyDeviceToHost);
    cudaMemcpy(Muscle, MuscleGPU, NumberOfMuscles * sizeof(muscleAttributesStructure), cudaMemcpyDeviceToHost);

    // Open file for writing (binary mode)
	// we're using a binary file (.bin) because it is faster and smaller than a text file, we can read and write the entire structs at once
	//rather than writing each variable one at a time, translating to and from text, and dealing with formatting
	//its also worth noting that any variable can be easily saved, so we can easily add anything to this
    FILE* file = fopen("simulation_state.bin", "wb");
    if (!file) 
	{
        printf("Error: Could not open file for saving state.\n");
        return;
    }

    // Save runtime value
    fwrite(&RunTime, sizeof(double), 1, file);
    
    // Save simulation timers and relevant state variables
	//this lets you save the mouse function you're in, I thought it might be useful for trigger placement, so I added it
    fwrite(&SimulationSwitch, sizeof(SimulationSwitch), 1, file);

    // Save node and muscle counts
    fwrite(&NumberOfNodes, sizeof(int), 1, file);
    fwrite(&NumberOfMuscles, sizeof(int), 1, file);

    // Save all nodes and muscles
    fwrite(Node, sizeof(nodeAttributesStructure), NumberOfNodes, file);
    fwrite(Muscle, sizeof(muscleAttributesStructure), NumberOfMuscles, file);

    fclose(file);
    //printf("Simulation state saved at runtime: %.2f ms\n", RunTime);
}

void loadState()
{
    // Open file for reading (binary mode)
    FILE* file = fopen("simulation_state.bin", "rb");
    if (!file) 
	{
        printf("Error: Could not open file for loading state.\n");
        return;
    }

    // Load runtime value
    fread(&RunTime, sizeof(double), 1, file);
    
    // Load simulation timers and relevant state variables
    fread(&SimulationSwitch, sizeof(SimulationSwitch), 1, file);

    // Load node and muscle counts
    int nNodes, nMuscles;
    fread(&nNodes, sizeof(int), 1, file);
    fread(&nMuscles, sizeof(int), 1, file);

    // Sanity check
    if (nNodes != NumberOfNodes || nMuscles != NumberOfMuscles) 
    {
        printf("Error: Node/Muscle count mismatch. State not loaded.\n");
        fclose(file);
        return;
    }

    // Load all nodes and muscles
    fread(Node, sizeof(nodeAttributesStructure), NumberOfNodes, file);
    fread(Muscle, sizeof(muscleAttributesStructure), NumberOfMuscles, file);

    fclose(file);

    // Copy loaded data back to GPU
    cudaMemcpy(NodeGPU, Node, NumberOfNodes * sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice);
    cudaMemcpy(MuscleGPU, Muscle, NumberOfMuscles * sizeof(muscleAttributesStructure), cudaMemcpyHostToDevice);

    drawPicture();
	SimulationSwitch.isPaused = true; // Pause the simulation after loading state
    //printf("Simulation state loaded at runtime: %.2f ms\n", RunTime);
}

void findNodes()
{
	copyNodesFromGPU();

	// Reset previously highlighted back/top nodes.
	if (SimulationSwitch.frontNodeIndex >= 0 && SimulationSwitch.frontNodeIndex < NumberOfNodes)
	{
		if (Node[SimulationSwitch.frontNodeIndex].isAblated)
		{
			Node[SimulationSwitch.frontNodeIndex].isDrawNode = true;
			Node[SimulationSwitch.frontNodeIndex].color.x = 1.0f;
			Node[SimulationSwitch.frontNodeIndex].color.y = 1.0f;
			Node[SimulationSwitch.frontNodeIndex].color.z = 1.0f;
		}
		else
		{
			Node[SimulationSwitch.frontNodeIndex].isDrawNode = false;
			Node[SimulationSwitch.frontNodeIndex].color.x = 0.0f;
			Node[SimulationSwitch.frontNodeIndex].color.y = 1.0f;
			Node[SimulationSwitch.frontNodeIndex].color.z = 0.0f;
		}
	}
	if (SimulationSwitch.topNodeIndex >= 0 && SimulationSwitch.topNodeIndex < NumberOfNodes)
	{
		if (Node[SimulationSwitch.topNodeIndex].isAblated)
		{
			Node[SimulationSwitch.topNodeIndex].isDrawNode = true;
			Node[SimulationSwitch.topNodeIndex].color.x = 1.0f;
			Node[SimulationSwitch.topNodeIndex].color.y = 1.0f;
			Node[SimulationSwitch.topNodeIndex].color.z = 1.0f;
		}
		else
		{
			Node[SimulationSwitch.topNodeIndex].isDrawNode = false;
			Node[SimulationSwitch.topNodeIndex].color.x = 0.0f;
			Node[SimulationSwitch.topNodeIndex].color.y = 1.0f;
			Node[SimulationSwitch.topNodeIndex].color.z = 0.0f;
		}
	}

	// Highlight the configured pulse/back/top nodes selected in config.
	if (PulsePointNode >= 0 && PulsePointNode < NumberOfNodes)
	{
		Node[PulsePointNode].isDrawNode = true;
		Node[PulsePointNode].color.x = 1.0f;
		Node[PulsePointNode].color.y = 0.85f;
		Node[PulsePointNode].color.z = 0.2f;
	}
	if (FrontNode >= 0 && FrontNode < NumberOfNodes)
	{
		Node[FrontNode].isDrawNode = true;
		Node[FrontNode].color.x = 1.0f;
		Node[FrontNode].color.y = 0.45f;
		Node[FrontNode].color.z = 0.2f;
	}
	if (UpNode >= 0 && UpNode < NumberOfNodes)
	{
		Node[UpNode].isDrawNode = true;
		Node[UpNode].color.x = 0.2f;
		Node[UpNode].color.y = 0.95f;
		Node[UpNode].color.z = 1.0f;
	}

	// Store indices for persistent display in the Utilities panel.
	SimulationSwitch.frontNodeIndex = FrontNode;
	SimulationSwitch.topNodeIndex = UpNode;
	SimulationSwitch.nodesFound = ((PulsePointNode >= 0 && PulsePointNode < NumberOfNodes) ||
		(FrontNode >= 0 && FrontNode < NumberOfNodes) ||
		(UpNode >= 0 && UpNode < NumberOfNodes));

	drawPicture();
	copyNodesToGPU();
}

// Hide pulse/back/top node markers by resetting them to normal colors
void hidePulseBackTopNodes()
{
	copyNodesFromGPU();

	// Reset pulse, back, and top nodes to their normal colors.
	if (PulsePointNode >= 0 && PulsePointNode < NumberOfNodes)
	{
		if (Node[PulsePointNode].isAblated)
		{
			Node[PulsePointNode].isDrawNode = true;
			Node[PulsePointNode].color.x = 1.0f;
			Node[PulsePointNode].color.y = 1.0f;
			Node[PulsePointNode].color.z = 1.0f;
		}
		else
		{
			Node[PulsePointNode].isDrawNode = false;
			Node[PulsePointNode].color.x = 0.0f;
			Node[PulsePointNode].color.y = 1.0f;
			Node[PulsePointNode].color.z = 0.0f;
		}
	}
	if (FrontNode >= 0 && FrontNode < NumberOfNodes)
	{
		if (Node[FrontNode].isAblated)
		{
			Node[FrontNode].isDrawNode = true;
			Node[FrontNode].color.x = 1.0f;
			Node[FrontNode].color.y = 1.0f;
			Node[FrontNode].color.z = 1.0f;
		}
		else
		{
			Node[FrontNode].isDrawNode = false;
			Node[FrontNode].color.x = 0.0f;
			Node[FrontNode].color.y = 1.0f;
			Node[FrontNode].color.z = 0.0f;
		}
	}
	if (UpNode >= 0 && UpNode < NumberOfNodes)
	{
		if (Node[UpNode].isAblated)
		{
			Node[UpNode].isDrawNode = true;
			Node[UpNode].color.x = 1.0f;
			Node[UpNode].color.y = 1.0f;
			Node[UpNode].color.z = 1.0f;
		}
		else
		{
			Node[UpNode].isDrawNode = false;
			Node[UpNode].color.x = 0.0f;
			Node[UpNode].color.y = 1.0f;
			Node[UpNode].color.z = 0.0f;
		}
	}

	// Clear the flag and indices.
	SimulationSwitch.nodesFound = false;
	SimulationSwitch.frontNodeIndex = -1;
	SimulationSwitch.topNodeIndex = -1;

	drawPicture();
	copyNodesToGPU();
}

/*
 This function directs the action that needs to be taken if a user hits a key on the key board.
 The terminal screen lists out all the keys and what they will do.
*/
void KeyPressed(GLFWwindow* window, int key, int scancode, int action, int mods)
{
	// See if GUI wants this event (Prevents keys from being registered when doing things like typing in a text box)
	ImGuiIO& io = ImGui::GetIO();
	if (io.WantCaptureKeyboard) return;

	// Only process key press events, not releases or repeats
	if (action != GLFW_PRESS) return;

	// Check for specific key presses
	switch (key) 
	{
		case GLFW_KEY_ESCAPE: // Shift + Escape to exit
			glfwSetWindowShouldClose(window, GLFW_TRUE);
			break;

		case GLFW_KEY_R: // r/R key to toggle run/pause
			if(SimulationSwitch.isPaused)
			{
				SimulationSwitch.isPaused = false;
			}
			else
			{
				SimulationSwitch.isPaused = true;
			}
			break;

		case GLFW_KEY_F2: // F2 key to draw only half of the nodes
			if(SimulationSwitch.DrawFrontHalfFlag)
			{
				SimulationSwitch.DrawFrontHalfFlag = false;
			}
			else
			{
				SimulationSwitch.DrawFrontHalfFlag = true;
			}
			drawPicture();
			break;

		case GLFW_KEY_F3: //show nodes 0 = none 1 = half 2 = all
			if(SimulationSwitch.DrawNodesFlag == 0)
			{
				SimulationSwitch.DrawNodesFlag = 1;
			}
			else if(SimulationSwitch.DrawNodesFlag == 1)
			{
				SimulationSwitch.DrawNodesFlag = 2;
			}
			else
			{
				SimulationSwitch.DrawNodesFlag = 0;
			}
			drawPicture();
			break;

		case GLFW_KEY_F4: // Toggle movie recording
			if(SimulationSwitch.isRecording)
			{
				movieOff();
			}
			else
			{
				movieOn();
			}
			break;

		case GLFW_KEY_F5: // Take a screenshot
			screenShot();
			break;

		case GLFW_KEY_F6: // Toggle ablate mode
			if(SimulationSwitch.isInAblateMode)
			{
				mouseFunctionsOff();
			}
			else
			{
				mouseAblateMode();
				SimulationSwitch.isInMouseFunctionMode = true;
			}
			break;
		case GLFW_KEY_F7: // F7 adjust area, Shift + F7 adjust line
			if (mods & GLFW_MOD_SHIFT)
			{
				if(SimulationSwitch.isInAdjustMuscleLineMode)
				{
					mouseFunctionsOff();
				}
				else
				{
					mouseAdjustMusclesLineModeMultiplier();
					SimulationSwitch.isInMouseFunctionMode = true;
				}
			}
			else
			{
				if(SimulationSwitch.isInAdjustMuscleAreaMode)
				{
					mouseFunctionsOff();
				}
				else
				{
					mouseAdjustMusclesAreaModeMultiplier();
					SimulationSwitch.isInMouseFunctionMode = true;
				}
			}
			break;
		
		case GLFW_KEY_F8: // F8 ectopic trigger, Shift + F8 ectopic beat
			if (mods & GLFW_MOD_SHIFT)
			{
				if(SimulationSwitch.isInEctopicBeatMode)
				{
					mouseFunctionsOff();
				}
				else
				{
					mouseEctopicBeatMode();
					SimulationSwitch.isInMouseFunctionMode = true;
				}
			}
			else
			{
				if(SimulationSwitch.isInEctopicEventMode)
				{
					mouseFunctionsOff();
				}
				else
				{
					mouseEctopicEventMode();
					SimulationSwitch.isInMouseFunctionMode = true;
				}
			}
			break;

		case GLFW_KEY_F9: // F9 identify muscle, Shift + F9 identify node
			if(SimulationSwitch.isInFindNodeMode || SimulationSwitch.isInFindMuscleMode)
			{
				mouseFunctionsOff();
			}
			else
			{
				(mods & GLFW_MOD_SHIFT) ? mouseIdentifyNodeMode() : mouseIdentifyMuscleMode();
				SimulationSwitch.isInMouseFunctionMode = true;
			}
			break;

		// Tab toggles between mouse mode and GUI mode
		case GLFW_KEY_TAB:
			if (SimulationSwitch.isInMouseFunctionMode) 
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
			}
			drawPicture();
			break;
        

		// Might make this a held key pending feedback
		case GLFW_KEY_KP_SUBTRACT:
		case GLFW_KEY_MINUS:
			if (mods & GLFW_MOD_CONTROL) // Ctrl + - : decrease beat period
			{
				Node[PulsePointNode].beatPeriod -= 10;
				if(Node[PulsePointNode].beatPeriod < 0)
				{
					Node[PulsePointNode].beatPeriod = 0;
				}
				copyNodesToGPU();
			}
			else if (mods & GLFW_MOD_SHIFT) // Shift + - : decrease simulation speed
			{
				DrawRate -= 50;
				if(DrawRate < 100) DrawRate = 100;
			}
			else // - : decrease selection radius
			{
				HitMultiplier -= 0.01;
				if(HitMultiplier < 0.01) HitMultiplier = 0.01;
			}
			break;

		case GLFW_KEY_KP_ADD:
		case GLFW_KEY_EQUAL:
			if (mods & GLFW_MOD_CONTROL) // Ctrl + = : increase beat period
			{
				Node[PulsePointNode].beatPeriod += 10;
				if(Node[PulsePointNode].beatPeriod > 10000)
				{
					Node[PulsePointNode].beatPeriod = 10000;
				}
				copyNodesToGPU();
			}
			else if (mods & GLFW_MOD_SHIFT) // Shift + = : increase simulation speed
			{
				DrawRate += 50;
				if(DrawRate > 5000) DrawRate = 5000;
			}
			else // = : increase selection radius
			{
				HitMultiplier += 0.025;
				if(HitMultiplier > 0.5) HitMultiplier = 0.5;
			}
			break;

		case GLFW_KEY_F: //Alt + f to find nodes
			if (mods & GLFW_MOD_ALT)
			{
				findNodes();
			}
			break;

		case GLFW_KEY_S: // Ctrl + S save state, Ctrl + Shift + S save settings
			if ((mods & GLFW_MOD_CONTROL) && (mods & GLFW_MOD_SHIFT))
			{
				saveRun();
			}
			else if (mods & GLFW_MOD_CONTROL)
			{
				saveState();
			}
			break;
		
		case GLFW_KEY_Z: // Ctrl + z to load state
			if (mods & GLFW_MOD_CONTROL)
			{
				loadState();
			}
			break;
		
		case GLFW_KEY_H: // H to collapse/expand GUI (was Ctrl+H)
			SimulationSwitch.guiCollapsed = !SimulationSwitch.guiCollapsed;
			break;

		// T key: Ctrl + T to show saved section colors.
		case GLFW_KEY_T:
			if (mods & GLFW_MOD_CONTROL)
			{
				SimulationSwitch.isPaused = true;
				// Reapply section colors that were saved in the loaded binary file.
				//showMuscleTypes();
				// Refresh the scene right away so the color change is visible immediately.
				drawPicture();
			}
			break;

		default: // For any other key, do nothing
			break;
		
	}
}

/*
	This function will process held keys.
	Since GLFW will not allow us to have 2 key call backs and seems to force us to use either presses or holds
	we will use this function to process held keys.

	We will need to consider all early exit cases for keys that don't need to be held and will need to handle shift keys in a different way

*/
void keyHeld(GLFWwindow* window)
{
	// Check if any movement keys (or keys we want to work if held) are pressed
    bool validKey = 
        glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS ||
        glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS ||
        glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS ||
        glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS ||
        glfwGetKey(window, GLFW_KEY_Z) == GLFW_PRESS ||
        glfwGetKey(window, GLFW_KEY_E) == GLFW_PRESS ||
        glfwGetKey(window, GLFW_KEY_X) == GLFW_PRESS ||
        glfwGetKey(window, GLFW_KEY_Y) == GLFW_PRESS ||
	glfwGetKey(window, GLFW_KEY_UP) == GLFW_PRESS ||
	glfwGetKey(window, GLFW_KEY_DOWN) == GLFW_PRESS ||
	glfwGetKey(window, GLFW_KEY_LEFT) == GLFW_PRESS ||
	glfwGetKey(window, GLFW_KEY_RIGHT) == GLFW_PRESS;

	//early exit if no valid key is pressed or if control is held down (to avoid conflict with ctrl+key shortcuts)
	if (!validKey || glfwGetKey(window, GLFW_KEY_LEFT_CONTROL) == GLFW_PRESS || glfwGetKey(window, GLFW_KEY_RIGHT_CONTROL) == GLFW_PRESS) return;

	bool shiftHeld = glfwGetKey(window, GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS || 
						glfwGetKey(window, GLFW_KEY_RIGHT_SHIFT) == GLFW_PRESS;

	// Copy nodes from GPU once per frame
    copyNodesFromGPU();

	float dAngle = 0.01;
	float zoom = 0.01*RadiusOfLeftAtrium;
	float temp;
	float4 lookVector;
	float d;
	float4 centerOfObject;
	
	//copyNodesMusclesFromGPU();
	
	lookVector.x = CenterX - EyeX;
	lookVector.y = CenterY - EyeY;
	lookVector.z = CenterZ - EyeZ;
	d = sqrt(lookVector.x*lookVector.x + lookVector.y*lookVector.y + lookVector.z*lookVector.z);
	
	if(d < 0.00001)
	{
		printf("\n The lookVector is too small.");
		printf("\n The simulation has been terminated.\n\n");
		exit(0);
	}
	else
	{
		lookVector.x /= d;
		lookVector.y /= d;
		lookVector.z /= d;
	}

	// WASD movement keys
	if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS || (glfwGetKey(window, GLFW_KEY_UP) == GLFW_PRESS && !shiftHeld))   // Rotate counterclockwise on the x-axis
	{
		centerOfObject = findCenterOfObject();
		for(int i = 0; i < NumberOfNodes; i++)
		{
			Node[i].position.x -= centerOfObject.x;
			Node[i].position.y -= centerOfObject.y;
			Node[i].position.z -= centerOfObject.z;
			temp = cos(dAngle)*Node[i].position.y - sin(dAngle)*Node[i].position.z;
			Node[i].position.z  = sin(dAngle)*Node[i].position.y + cos(dAngle)*Node[i].position.z;
			Node[i].position.y  = temp;
			Node[i].position.x += centerOfObject.x;
			Node[i].position.y += centerOfObject.y;
			Node[i].position.z += centerOfObject.z;
		}
		AngleOfSimulation.x += dAngle;
	}

	if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS  || (glfwGetKey(window, GLFW_KEY_LEFT) == GLFW_PRESS && !shiftHeld))   // Rotate clockwise on the y-axis
	{
		centerOfObject = findCenterOfObject();
		for(int i = 0; i < NumberOfNodes; i++)
		{
			Node[i].position.x -= centerOfObject.x;
			Node[i].position.y -= centerOfObject.y;
			Node[i].position.z -= centerOfObject.z;
			temp = cos(dAngle)*Node[i].position.x + sin(dAngle)*Node[i].position.z;
			Node[i].position.z  = -sin(dAngle)*Node[i].position.x + cos(dAngle)*Node[i].position.z;
			Node[i].position.x  = temp;
			Node[i].position.x += centerOfObject.x;
			Node[i].position.y += centerOfObject.y;
			Node[i].position.z += centerOfObject.z;
		}
		AngleOfSimulation.y += dAngle;
	}

	if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS  || (glfwGetKey(window, GLFW_KEY_DOWN) == GLFW_PRESS && !shiftHeld))  // Rotate clockwise on the x-axis
	{
		centerOfObject = findCenterOfObject();
		for(int i = 0; i < NumberOfNodes; i++)
		{
			Node[i].position.x -= centerOfObject.x;
			Node[i].position.y -= centerOfObject.y;
			Node[i].position.z -= centerOfObject.z;
			temp = cos(-dAngle)*Node[i].position.y - sin(-dAngle)*Node[i].position.z;
			Node[i].position.z  = sin(-dAngle)*Node[i].position.y + cos(-dAngle)*Node[i].position.z;
			Node[i].position.y  = temp; 
			Node[i].position.x += centerOfObject.x;
			Node[i].position.y += centerOfObject.y;
			Node[i].position.z += centerOfObject.z;
		}
		AngleOfSimulation.x -= dAngle;
	}
	
	if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS  || (glfwGetKey(window, GLFW_KEY_RIGHT) == GLFW_PRESS && !shiftHeld))  // Rotate counterclockwise on the y-axis
	{
		centerOfObject = findCenterOfObject();
		for(int i = 0; i < NumberOfNodes; i++)
		{
			Node[i].position.x -= centerOfObject.x;
			Node[i].position.y -= centerOfObject.y;
			Node[i].position.z -= centerOfObject.z;
			temp =  cos(-dAngle)*Node[i].position.x + sin(-dAngle)*Node[i].position.z;
			Node[i].position.z  = -sin(-dAngle)*Node[i].position.x + cos(-dAngle)*Node[i].position.z;
			Node[i].position.x  = temp;
			Node[i].position.x += centerOfObject.x;
			Node[i].position.y += centerOfObject.y;
			Node[i].position.z += centerOfObject.z;
		}
		AngleOfSimulation.y -= dAngle;
	}
	
	if (glfwGetKey(window, GLFW_KEY_Z) == GLFW_PRESS) 
	{
		if(shiftHeld)  // Uppercase Z - Rotate clockwise on the z-axis
		{
			centerOfObject = findCenterOfObject();
			for(int i = 0; i < NumberOfNodes; i++)
			{
				Node[i].position.x -= centerOfObject.x;
				Node[i].position.y -= centerOfObject.y;
				Node[i].position.z -= centerOfObject.z;
				temp = cos(-dAngle)*Node[i].position.x - sin(-dAngle)*Node[i].position.y;
				Node[i].position.y  = sin(-dAngle)*Node[i].position.x + cos(-dAngle)*Node[i].position.y;
				Node[i].position.x  = temp;
				Node[i].position.x += centerOfObject.x;
				Node[i].position.y += centerOfObject.y;
				Node[i].position.z += centerOfObject.z;
			}
			AngleOfSimulation.z -= dAngle;
		}
		else  // Lowercase z - Rotate counterclockwise on the z-axis
		{
			centerOfObject = findCenterOfObject();
			for(int i = 0; i < NumberOfNodes; i++)
			{
				Node[i].position.x -= centerOfObject.x;
				Node[i].position.y -= centerOfObject.y;
				Node[i].position.z -= centerOfObject.z;
				temp = cos(dAngle)*Node[i].position.x - sin(dAngle)*Node[i].position.y;
				Node[i].position.y  = sin(dAngle)*Node[i].position.x + cos(dAngle)*Node[i].position.y;
				Node[i].position.x  = temp;
				Node[i].position.x += centerOfObject.x;
				Node[i].position.y += centerOfObject.y;
				Node[i].position.z += centerOfObject.z;
			}
			AngleOfSimulation.z += dAngle;
		}
	}
	
	float dx = 5.0;
	float dy = 5.0;
	if (glfwGetKey(window, GLFW_KEY_X) == GLFW_PRESS) 
	{
		if(shiftHeld)  // Uppercase E - Zoom out
		{
			for(int i = 0; i < NumberOfNodes; i++)
			{
				Node[i].position.x += dx; //zoom*lookVector.x;
				//Node[i].position.y += zoom*lookVector.y;
				//Node[i].position.z += zoom*lookVector.z;
			}
			CenterOfSimulation.x += dx;
			//CenterOfSimulation.y += zoom*lookVector.y;
			//CenterOfSimulation.z += zoom*lookVector.z;
		}
		else  // Lowercase e - Zoom in
		{
			for(int i = 0; i < NumberOfNodes; i++)
			{
				Node[i].position.x -= dx;
				//Node[i].position.y -= zoom*lookVector.y;
				//Node[i].position.z -= zoom*lookVector.z;
			}
			CenterOfSimulation.x -= dx;
			//CenterOfSimulation.y -= zoom*lookVector.y;
			//CenterOfSimulation.z -= zoom*lookVector.z;
		}
	}
	
	if (glfwGetKey(window, GLFW_KEY_Y) == GLFW_PRESS) 
	{
		if(shiftHeld)  // Uppercase E - Zoom out
		{
			for(int i = 0; i < NumberOfNodes; i++)
			{
				Node[i].position.y += dy; //zoom*lookVector.x;
				//Node[i].position.y += zoom*lookVector.y;
				//Node[i].position.z += zoom*lookVector.z;
			}
			CenterOfSimulation.y += dy;
			//CenterOfSimulation.y += zoom*lookVector.y;
			//CenterOfSimulation.z += zoom*lookVector.z;
		}
		else  // Lowercase e - Zoom in
		{
			for(int i = 0; i < NumberOfNodes; i++)
			{
				Node[i].position.y -= dy;
				//Node[i].position.y -= zoom*lookVector.y;
				//Node[i].position.z -= zoom*lookVector.z;
			}
			CenterOfSimulation.y -= dy;
			//CenterOfSimulation.y -= zoom*lookVector.y;
			//CenterOfSimulation.z -= zoom*lookVector.z;
		}
	}
	
	
	
	
	if (glfwGetKey(window, GLFW_KEY_E) == GLFW_PRESS) 
	{
		if(shiftHeld)  // Uppercase E - Zoom out
		{
			for(int i = 0; i < NumberOfNodes; i++)
			{
				Node[i].position.x += zoom*lookVector.x;
				Node[i].position.y += zoom*lookVector.y;
				Node[i].position.z += zoom*lookVector.z;
			}
			CenterOfSimulation.x += zoom*lookVector.x;
			CenterOfSimulation.y += zoom*lookVector.y;
			CenterOfSimulation.z += zoom*lookVector.z;
		}
		else  // Lowercase e - Zoom in
		{
			for(int i = 0; i < NumberOfNodes; i++)
			{
				Node[i].position.x -= zoom*lookVector.x;
				Node[i].position.y -= zoom*lookVector.y;
				Node[i].position.z -= zoom*lookVector.z;
			}
			CenterOfSimulation.x -= zoom*lookVector.x;
			CenterOfSimulation.y -= zoom*lookVector.y;
			CenterOfSimulation.z -= zoom*lookVector.z;
		}
	}
	
	
	
	

	if (shiftHeld) 
	{
		// Shift + Left/Right for Z-axis rotation (same as z/Z)
		if (glfwGetKey(window, GLFW_KEY_RIGHT) == GLFW_PRESS) 
		{
			// Rotate clockwise on the z-axis (same as uppercase Z)
			centerOfObject = findCenterOfObject();
			for(int i = 0; i < NumberOfNodes; i++) 
			{
				Node[i].position.x -= centerOfObject.x;
				Node[i].position.y -= centerOfObject.y;
				Node[i].position.z -= centerOfObject.z;
				temp = cos(-dAngle)*Node[i].position.x - sin(-dAngle)*Node[i].position.y;
				Node[i].position.y = sin(-dAngle)*Node[i].position.x + cos(-dAngle)*Node[i].position.y;
				Node[i].position.x = temp;
				Node[i].position.x += centerOfObject.x;
				Node[i].position.y += centerOfObject.y;
				Node[i].position.z += centerOfObject.z;
			}
			AngleOfSimulation.z -= dAngle;
		}
		
		if (glfwGetKey(window, GLFW_KEY_LEFT) == GLFW_PRESS) 
		{
			// Rotate counterclockwise on the z-axis (same as lowercase z)
			centerOfObject = findCenterOfObject();
			for(int i = 0; i < NumberOfNodes; i++) 
			{
				Node[i].position.x -= centerOfObject.x;
				Node[i].position.y -= centerOfObject.y;
				Node[i].position.z -= centerOfObject.z;
				temp = cos(dAngle)*Node[i].position.x - sin(dAngle)*Node[i].position.y;
				Node[i].position.y = sin(dAngle)*Node[i].position.x + cos(dAngle)*Node[i].position.y;
				Node[i].position.x = temp;
				Node[i].position.x += centerOfObject.x;
				Node[i].position.y += centerOfObject.y;
				Node[i].position.z += centerOfObject.z;
			}
			AngleOfSimulation.z += dAngle;
		}
		
		// Shift + Up/Down for zooming (same as e/E)
		if (glfwGetKey(window, GLFW_KEY_UP) == GLFW_PRESS) 
		{
			// Zoom in (same as lowercase e)
			for(int i = 0; i < NumberOfNodes; i++) 
			{
				Node[i].position.x -= zoom*lookVector.x;
				Node[i].position.y -= zoom*lookVector.y;
				Node[i].position.z -= zoom*lookVector.z;
			}
			CenterOfSimulation.x -= zoom*lookVector.x;
			CenterOfSimulation.y -= zoom*lookVector.y;
			CenterOfSimulation.z -= zoom*lookVector.z;
		}
		
		if (glfwGetKey(window, GLFW_KEY_DOWN) == GLFW_PRESS) 
		{
			// Zoom out (same as uppercase E)
			for(int i = 0; i < NumberOfNodes; i++) 
			{
				Node[i].position.x += zoom*lookVector.x;
				Node[i].position.y += zoom*lookVector.y;
				Node[i].position.z += zoom*lookVector.z;
			}
			CenterOfSimulation.x += zoom*lookVector.x;
			CenterOfSimulation.y += zoom*lookVector.y;
			CenterOfSimulation.z += zoom*lookVector.z;
		}
	}

	drawPicture(); // Redraw the picture after all the changes
	copyNodesToGPU(); // Copy the modified nodes back to the GPU

}

/*
 This function is called when the mouse moves without any button pressed.
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
 This function does an action based on the mode the viewer is in and which mouse button the user pressed.
*/
void myMouse(GLFWwindow* window, int button, int action, int mods)
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
		
		printf("\nC\n");
		copyNodesMusclesFromGPU();
		printf("\nD\n");
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

void scrollWheel(GLFWwindow* window, double xoffset, double yoffset)
{
    bool ctrlHeld = (glfwGetKey(window, GLFW_KEY_LEFT_CONTROL) == GLFW_PRESS || 
                     glfwGetKey(window, GLFW_KEY_RIGHT_CONTROL) == GLFW_PRESS);
    
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
