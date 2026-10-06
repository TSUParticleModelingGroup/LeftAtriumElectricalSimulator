/*
 This file contains:

 1: All the functions that determine how to orient and view the simulation.
 2: All the functions that draw the actual simulation. 
 3: The functions that print to the linux terminal all the setting of the simulation.
 In short this file holds the functions that present information to the user.
 
 The functions are listed below in the order they appear.
 void ShowTooltip(const char*);
 void ShowIdentifiedNodesBox();
 void ShowIdentifiedMusclesBox();
 void renderSphere(float, int, int);
 void createSphereVBO(float, int, int);
 void renderSphereVBO();
 void frustumView();
 void drawPicture();
 void createGUI();
*/


// Helper function to show a tooltip in ImGui
void ShowTooltip(const char* text) 
{
	if (ImGui::IsItemHovered()) 
	{
		ImGui::BeginTooltip();
		ImGui::TextUnformatted(text);
		ImGui::EndTooltip();
	}
}

// Display box for identified nodes in FindNodeMode
void ShowIdentifiedNodesBox()
{
	ImGui::TextColored(ImVec4(1.0f, 0.5f, 1.0f, 1.0f), "Click on nodes to identify them");
	ImGui::BeginChild("IdentifiedNodes", ImVec2(0, 120), true);
	int k = 0;
	for (int i = 0; i < NumberOfNodes; i++)
	{
		// if the node is colored magenta, it is identified. Magenta color: (1.0, 0.0, 1.0)
		if (Node[i].isDrawNode && Node[i].color.x == 1.0f && Node[i].color.y == 0.0f && Node[i].color.z == 1.0f)
		{
			ImGui::Text("Node ID: %d", i);
			k++;
		}
	}
	ImGui::Text("Number of Nodes identified = %d", k);
	ImGui::EndChild();
	if (ImGui::Button("Clear Identified Nodes"))
	{
		for (int i = 0; i < NumberOfNodes; i++)
		{
			if (Node[i].isDrawNode && Node[i].color.x == 1.0f && Node[i].color.y == 0.0f && Node[i].color.z == 1.0f)
			{
				if (Node[i].isAblated)
				{
					Node[i].color.x = 1.0f;
					Node[i].color.y = 1.0f;
					Node[i].color.z = 1.0f;
				}
				else
				{
					Node[i].isDrawNode = false;
					Node[i].color.x = 0.0f;
					Node[i].color.y = 1.0f;
					Node[i].color.z = 0.0f;
				}
			}
		}
		copyNodesMusclesToGPU();
		drawPicture();
	}
}

// Display box for identified muscles in FindMuscleMode
void ShowIdentifiedMusclesBox()
{
	ImGui::TextColored(ImVec4(0.3f, 0.3f, 1.0f, 1.0f), "Click on muscles to identify them");
	ImGui::BeginChild("IdentifiedMuscles", ImVec2(0, 120), true);
	int k = 0;
	for (int i = 0; i < NumberOfMuscles; i++)
	{
		//if the muscle is colored blue, it is identified. Blue color: (0.0, 0.0, 0.7)
		if (Muscle[i].color.x == 0.0f && Muscle[i].color.y == 0.0f && Muscle[i].color.z == 0.7f)
		{
			ImGui::Text("Muscle ID: %d | CV: %.3f | RP: %.3f", i, Muscle[i].conductionVelocity, Muscle[i].refractoryPeriod/300.0f);
			k++;
		}
	}
	ImGui::Text("Number of Muscles identified = %d", k);
	ImGui::EndChild();
	if (ImGui::Button("Clear Identified Muscles"))
	{
		for (int i = 0; i < NumberOfMuscles; i++)
		{
			if (Muscle[i].color.x == 0.0f && Muscle[i].color.y == 0.0f && Muscle[i].color.z == 0.7f)
			{
				Muscle[i].color.x = 0.7f;
				Muscle[i].color.y = 0.7f;
				Muscle[i].color.z = 0.7f;
			}
		}
		copyNodesMusclesToGPU();
		drawPicture();
	}
}

// Add this to a utility file, only used for the mouse selection since it's just 1 object
void renderSphere(float radius, int slices, int stacks) 
{
    // Sphere geometry parameters
    float x, y, z, alpha, beta; // Storage for coordinates and angles
    float sliceStep = 2.0f * PI / slices;
    float stackStep = PI / stacks;

    for (int i = 0; i < stacks; ++i) {
        alpha = i * stackStep;
        beta = alpha + stackStep;

        glBegin(GL_TRIANGLE_STRIP);
        for (int j = 0; j <= slices; ++j) {
            float theta = (j == slices) ? 0.0f : j * sliceStep;

            // Vertex 1
            x = -sin(alpha) * cos(theta);
            y = cos(alpha);
            z = sin(alpha) * sin(theta);
            glNormal3f(x, y, z);
            glVertex3f(x * radius, y * radius, z * radius);

            // Vertex 2
            x = -sin(beta) * cos(theta);
            y = cos(beta);
            z = sin(beta) * sin(theta);
            glNormal3f(x, y, z);
            glVertex3f(x * radius, y * radius, z * radius);
        }
        glEnd();
    }
}

/*
	Function to render a sphere using a VBO
	This function creates a VBO for a sphere and binds it for rendering.

	This code creates vertices and indices to make a sphere using triangle strips.
	It uses OpenGL functions to create and bind the VBO and IBO (what makes up the sphere).
	The sphere stays in the GPU memory and is faster to render and puts less load on the CPU.
*/
void createSphereVBO(float radius, int slices, int stacks)
{
    std::vector<float> vertices;
    std::vector<unsigned int> indices;
    
    // Generate sphere vertices with positions and normals
	for (int i = 0; i <= stacks; ++i) 
	{
		// Calculate the vertical angle phi (0 to PI, from top to bottom of sphere)
		float phi = PI * i / stacks;
		float sinPhi = sin(phi);
		float cosPhi = cos(phi);
		
		for (int j = 0; j <= slices; ++j) 
		{
			// Calculate the horizontal angle theta (0 to 2PI, around the sphere)
			float theta = 2.0f * PI * j / slices;
			float sinTheta = sin(theta);
			float cosTheta = cos(theta);
			
			// Convert spherical to Cartesian coordinates
			// x = r * sin(phi) * cos(theta)
			// y = r * cos(phi)          // y is up/down axis (poles of the sphere)
			// z = r * sin(phi) * sin(theta)
			float x = radius * sinPhi * cosTheta;
			float y = radius * cosPhi;
			float z = radius * sinPhi * sinTheta;
			
			// For a sphere, normal vectors point outward from center
			// and are simply the normalized position vector (position/radius)
			float nx = sinPhi * cosTheta;  // Same as x/radius
			float ny = cosPhi;             // Same as y/radius
			float nz = sinPhi * sinTheta;  // Same as z/radius
			
			// Store the vertex data in interleaved format:
			// Each vertex has 6 floats - 3 for position (x,y,z) and 3 for normal (nx,ny,nz)
			vertices.push_back(x);
			vertices.push_back(y);
			vertices.push_back(z);
			vertices.push_back(nx);
			vertices.push_back(ny);
			vertices.push_back(nz);
		}
	}
    
	// Generate indices for triangle strips
	// This section creates triangles by connecting the grid of vertices:
	// - First defines index values that point to positions in the vertex array 
	// - Creates two triangles for each grid cell (rectangular patch)
	// - Each triangle is defined by three indices in counter-clockwise order
	for (int i = 0; i < stacks; ++i) 
	{
		for (int j = 0; j < slices; ++j) 
		{
			// Calculate indices for the four corners of the current grid cell
			int first = i * (slices + 1) + j;          // Current vertex
			int second = first + slices + 1;           // Vertex below current
			
			// First triangle: Connect current vertex, vertex below, and vertex to the right
			indices.push_back(first);
			indices.push_back(second);
			indices.push_back(first + 1);
			
			// Second triangle: Connect vertex below, vertex below+right, and vertex to the right
			indices.push_back(second);
			indices.push_back(second + 1);
			indices.push_back(first + 1);
		}
	}

	// Store the total counts for rendering
	NumSphereVertices = vertices.size() / 6; // 6 floats per vertex (pos + normal)
	NumSphereIndices = indices.size();

	// Create and setup OpenGL buffers on the GPU
	// - Generate unique buffer IDs
	// - Bind buffers to set them as active
	// - Copy data from CPU arrays to GPU memory
	glGenBuffers(1, &SphereVBO);  // Generate Vertex Buffer Object for storing positions and normals
	glBindBuffer(GL_ARRAY_BUFFER, SphereVBO);
	glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);

	// Same process for the index buffer
	glGenBuffers(1, &SphereIBO);  // Generate Index Buffer Object for storing triangle connections
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, SphereIBO);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(unsigned int), indices.data(), GL_STATIC_DRAW);

	// Unbind buffers to prevent accidental modification
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
}

void renderSphereVBO() 
{
    // Bind the VBO and IBO
    glBindBuffer(GL_ARRAY_BUFFER, SphereVBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, SphereIBO);
    
    // Enable vertex and normal arrays
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_NORMAL_ARRAY);
    
    // Set up pointers to vertex and normal data
    glVertexPointer(3, GL_FLOAT, 6 * sizeof(float), 0);
    glNormalPointer(GL_FLOAT, 6 * sizeof(float), (void*)(3 * sizeof(float)));
    
    // Draw the sphere
    glDrawElements(GL_TRIANGLES, NumSphereIndices, GL_UNSIGNED_INT, 0);
    
    // Disable arrays
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_NORMAL_ARRAY);
    
    // Unbind buffers
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
}

/*
 This function sets your view to frustum.This is the view the your eyes actually see. Where train tracks pull in 
 towards each other as they move off in the distance. It is how we see but can cause problems when using the mouse
 which lives in 2D to locate an object that lives in 3D.
*/
void frustumView()
{
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glFrustum(-0.2, 0.2, -0.2, 0.2, Near, Far);
	glMatrixMode(GL_MODELVIEW);
	SimulationSwitch.ViewFlag = 1;
	drawPicture();
}

/*
 This function draws the LA to the screen. It also saves movie frames if a movie is being recorded.
*/
void drawPicture()
{
	//int nodeNumber;
	int muscleNumber;
	int k;
	glClear(GL_COLOR_BUFFER_BIT);
	glClear(GL_DEPTH_BUFFER_BIT);
	
	//if(!SimulationSwitch.isPaused) glColor3d(0.0,1.0,0.0); // Green is running
	//else glColor3d(1.0,0.0,0.0); // Red is paused	
	glColor3d(Node[PulsePointNode].color.x, Node[PulsePointNode].color.y, Node[PulsePointNode].color.z);
	glPushMatrix();
	glTranslatef(Node[PulsePointNode].position.x, Node[PulsePointNode].position.y, Node[PulsePointNode].position.z);
	renderSphereVBO();
	glPopMatrix();
	
	// Drawing center node
	//This draws a node at the center of the simulation for debugging purposes
	if(false) // false turns it off, true turns it on.
	{
		glColor3d(0.0,0.0,1.0);
		glPushMatrix();
		glTranslatef(CenterOfSimulation.x, CenterOfSimulation.y, CenterOfSimulation.z);
		renderSphereVBO();
		glPopMatrix();
	}
	
	// Drawing nodes
	if(SimulationSwitch.DrawNodesFlag == 1 || SimulationSwitch.DrawNodesFlag == 2)  //if we're drawing half(1) or all(2) of the nodes
	{
		for(int i = 0; i < NumberOfNodes; i++) // Start at 1 to skip the pulse node and go through all nodes
		{
			if(SimulationSwitch.DrawFrontHalfFlag == 1 || SimulationSwitch.DrawNodesFlag == 1) //If we're only drawing the nodes on the front half.
			{
				if(CenterOfSimulation.z - 0.001 < Node[i].position.z)  //Draw only the nodes in the front half.
				{
					glColor3d(Node[i].color.x, Node[i].color.y, Node[i].color.z);
					glPushMatrix();
					glTranslatef(Node[i].position.x, Node[i].position.y, Node[i].position.z);
					renderSphereVBO();
					glPopMatrix();
				}
			}
			else //draw all nodes
			{
				glColor3d(Node[i].color.x, Node[i].color.y, Node[i].color.z);
				glPushMatrix();
				glTranslatef(Node[i].position.x, Node[i].position.y, Node[i].position.z);
				renderSphereVBO();
				glPopMatrix();
			}	
		}
	}
	// If the nodes are not drawn as spheres you will be in this else case.
	// Now some of the node we still draw as points, like node that have been ablated, ectopic nodes, or nodes connected to muscle
	// that have been adjusted. This helps the user keep track of what has been done. This is what is done here and is based on
	// the .isDrawNode flag.
	else 
	{
		glPointSize(NodePointSize);
		glBegin(GL_POINTS);
	 	for(int i = 0; i < NumberOfNodes; i++)
		{
			if(SimulationSwitch.DrawFrontHalfFlag == 1)
			{
				if(CenterOfSimulation.z - 0.001 < Node[i].position.z)  // Only drawing the nodes in the front half.
				{
					glColor3d(Node[i].color.x, Node[i].color.y, Node[i].color.z);
					if(Node[i].isDrawNode)
					{
						glVertex3f(Node[i].position.x, Node[i].position.y, Node[i].position.z);
					}
				}
			}
			else
			{
				glColor3d(Node[i].color.x, Node[i].color.y, Node[i].color.z);
				if(Node[i].isDrawNode)
				{
					glVertex3f(Node[i].position.x, Node[i].position.y, Node[i].position.z);
				}
			}
		}
		glEnd();
	}
	
	// Drawing muscles
	glLineWidth(LineWidth);
	for(int i = 0; i < NumberOfNodes; i++)
	{
		for(int j = 0; j < MUSCLES_PER_NODE; j++)
		{
			muscleNumber = Node[i].muscle[j];
			if(muscleNumber != -1)
			{
				k = Muscle[muscleNumber].nodeA;
				if(k == i) 
				{
					k = Muscle[muscleNumber].nodeB;
				}
				
				if(SimulationSwitch.DrawFrontHalfFlag == 1)
				{
					if(CenterOfSimulation.z - 0.001 < Node[i].position.z && CenterOfSimulation.z - 0.001 < Node[k].position.z)  // Only drawing the nodes in the front half.
					{
						glColor3d(Muscle[muscleNumber].color.x, Muscle[muscleNumber].color.y, Muscle[muscleNumber].color.z);
						glBegin(GL_LINES);
							glVertex3f(Node[i].position.x, Node[i].position.y, Node[i].position.z);
							glVertex3f(Node[k].position.x, Node[k].position.y, Node[k].position.z);
						glEnd();
					}
				}
				else
				{
					glColor3d(Muscle[muscleNumber].color.x, Muscle[muscleNumber].color.y, Muscle[muscleNumber].color.z);
					glBegin(GL_LINES);
						glVertex3f(Node[i].position.x, Node[i].position.y, Node[i].position.z);
						glVertex3f(Node[k].position.x, Node[k].position.y, Node[k].position.z);
					glEnd();
					
				}
			}
		}	
	}
	
	// BMW
// Just stuck this in to track the Action Potintial it will need cleaning up
// It does all muscle and is not turned off if you are only looking at the front half.
// It has not on off button in the simulationSwitchesStructure or a button on the GUI.
// Start ******************
	
	SimulationSwitch.isDrawAP = 1;
	float distance;
	float x,y,z,dx,dy,dz,d;
	int id1, id2;
	glColor3d(0.0, 0.0, 1.0);
	glPointSize(5.0);
	glBegin(GL_POINTS);
	if(SimulationSwitch.isDrawAP)
	{
		for(int i = 0; i < NumberOfMuscles; i++)
		{
			if(0.0 < Muscle[i].timer && Muscle[i].timer < Muscle[i].conductionDuration)
			{
				distance = Muscle[i].conductionVelocity*Muscle[i].timer;
				if(Muscle[i].apNode == Muscle[i].nodeA)
				{
					id1 = Muscle[i].nodeA;
					id2 = Muscle[i].nodeB;
				}
				else
				{
					id1 = Muscle[i].nodeB;
					id2 = Muscle[i].nodeA;
				}
				dx = Node[id2].position.x - Node[id1].position.x;
				dy = Node[id2].position.y - Node[id1].position.y;
				dz = Node[id2].position.z - Node[id1].position.z;
				d = sqrt(dx*dx + dy*dy + dz*dz);
				
				x = Node[id1].position.x + distance*(dx/d);
				y = Node[id1].position.y + distance*(dy/d);
				z = Node[id1].position.z + distance*(dz/d);
				
				glVertex3f(x, y, z);
			}
		}
	}
	glEnd();
// STop *****************************

	// Puts a ball at the location of the mouse if a mouse function is on.
	if(SimulationSwitch.isInMouseFunctionMode)
	{
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    		glEnable(GL_DEPTH_TEST);
		glColor4f(1.0, 1.0, 1.0, 1.0);
		glPushMatrix();
		glTranslatef(MouseX, MouseY, MouseZ);
		
		renderSphere(HitMultiplier*RadiusOfLeftAtrium,20,20);
		//renderSphere(5.0*NodeRadiusAdjustment*RadiusOfAtria,20,20);
		glPopMatrix();
		glDisable(GL_BLEND);
	}
	
	// Saves the picture if a movie is being recorded.
	if(SimulationSwitch.isRecording)
	{
		// Read pixels at the locked capture resolution so videos/screenshots stay consistent
		glReadPixels(0, 0, CaptureWidth, CaptureHeight, GL_RGBA, GL_UNSIGNED_BYTE, Buffer);
		fwrite(Buffer, 4 * CaptureWidth * CaptureHeight, 1, MovieFile);
	}
}

/* 
	 This function creates the GUI using ImGui.
	 This is where the actual window is built

	 All ImGui fields need to be in an if statement to check if the value has changed.
	 ImGui::CollapsingHeader to create a collapsible section
	 ImGui::Text to display text
	 ImGui::Input<Type> to create input fields for user input
	 ImGui::Slider<Type> to create sliders for user input
	 ImGui::Checkbox to create checkboxes for toggling options (must be bools)
	 ImGui::Combo to create dropdown menus for selecting options (must be int pointers)
	 ImGui::Button to create buttons for actions
	 ImGui::TextColored to display colored text (use vec4 to apply the color)
	 ImGui::SameLine to place elements on the same line
	 ImGui::isItemHovered to check if an item is hovered over (used for tooltips)

	 For buttons and checkboxes, its best to use ternary operators when posssible
*/
void createGUI()
{
	// Get actual viewport size -- this is the size of the window, not the size of the the openGL viewport
	const ImGuiViewport* viewport = ImGui::GetMainViewport();

	//Set in top right corner of the window, 10px offset from both edges
	//ImGUICond_Always means the position will always be set to this value, regardless of previous positions
	//last arg anchors to the right and top of the window
	ImGui::SetNextWindowPos(ImVec2(viewport->WorkPos.x + viewport->WorkSize.x - 10, viewport->WorkPos.y + 10), ImGuiCond_Always,  ImVec2(1.0f, 0.0f));

	// Setup ImGui window flags
	ImGuiWindowFlags window_flags = 0; // Initialize window flags to 0, flags are used to set window properties, like size, position, etc. 0 means no flags are set
	window_flags = ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoFocusOnAppearing; // Always resize the window to fit the content

	//comment this out if you would like to allow the user to unhide the GUI while in mouse mode, can cause problems
	if(SimulationSwitch.isInMouseFunctionMode) SimulationSwitch.guiCollapsed = true;
	
	ImGui::SetNextWindowCollapsed(SimulationSwitch.guiCollapsed, ImGuiCond_Always);

	// Main GUI Controls Window Begins
	ImGui::Begin("Control Panel", NULL, window_flags); //title of the window, NULL means no pointer to a bool to close the window, window_flags are the flags we set above
    
		//update bool to match current state (makes sure clicking also works in addition to ctrl + h)
		SimulationSwitch.guiCollapsed = ImGui::IsWindowCollapsed();

		// Run/Pause button
		if (ImGui::Button(SimulationSwitch.isPaused ? "Run" : "Pause")) //print whats happening
		{
			SimulationSwitch.isPaused = !SimulationSwitch.isPaused;
		}
		ShowTooltip("r/R");
    
		// General simulation controls
		if (ImGui::CollapsingHeader("Simulation Controls", ImGuiTreeNodeFlags_DefaultOpen)) //open by default
		{
			// View controls
			//Needed because ImGui needs a bool for a checkbox, can make a dropbox if more display options are needed
			bool frontHalf = SimulationSwitch.DrawFrontHalfFlag == 1; 
			//checkbox for if we only want to draw the first half of the nodes
			if(ImGui::Checkbox("Draw Front Half Only", &frontHalf)) 
			{
				//when the button is pressed it will change the value of frontHalf to the opposite of what it was before
				SimulationSwitch.DrawFrontHalfFlag = frontHalf ? 1 : 0;
				drawPicture();
			}
        
			// Node display options
			const char* nodeOptions[] = { "Off", "Half", "Full" }; //array of options for the dropdown menu
			int nodeDisplay = SimulationSwitch.DrawNodesFlag;

			//Combo makes a dropdown menu with the options in the array
			if(ImGui::Combo("Show Nodes", &nodeDisplay, nodeOptions, 3)) //args are menu name, pointer to the selected option, array of text options, # of options
			{
				if (nodeDisplay != SimulationSwitch.DrawNodesFlag) // Only update if the value changes
				{
					SimulationSwitch.DrawNodesFlag = nodeDisplay;
					drawPicture();
				}
			}
        
			// Button for recording
			if (ImGui::Button(SimulationSwitch.isRecording ? "Stop Recording" : "Record Video"))
			{
				if (SimulationSwitch.isRecording)
				{
					movieOff();
				}
				else
				{
					movieOn();
				}
			}

			// Quality preset dropdown
			ImGui::SameLine();
			const char* presetOptions[] = { "Low (1080p@60)", "Medium (1440p@60)", "High (4K@60)", "SC (4K, specific encoding)" };
			ImGui::Combo("##QualityPreset", &QualityPreset, presetOptions, 4);
			ShowTooltip("Select the shared recording/screenshot quality preset");

			// Screenshot button
			if (ImGui::Button("Screenshot"))
			{
				screenShot();
			}
		}

		//Draw Rate Slider
		ImGui::Separator();
		ImGui::Text("Simulation Speed");
		if (ImGui::SliderInt("##DrawRateSlider", &DrawRate, 1, 5000, "%d")) //slider for setting the simulation rate
		{
			//bound slider values
			if (DrawRate < 1) DrawRate = 1;
			if (DrawRate > 5000) DrawRate = 5000;
		}
		 
		// Mouse mode selection
		if (ImGui::CollapsingHeader("Mouse Functions", ImGuiTreeNodeFlags_DefaultOpen))
		{
			// Display current mouse mode
			ImGui::Text("Current Mode: ");

			if (SimulationSwitch.isInAblateMode) 
			{
				ImGui::SameLine();
				ImGui::TextColored(ImVec4(0.0f, 1.0f, 0.0f, 1.0f), "Ablate Mode");
				//ImGui::Text("(Left Click: Ablate, Right Click: Undo)");
			}
			else if (SimulationSwitch.isInEctopicBeatMode) 
			{
				ImGui::SameLine();
				ImGui::TextColored(ImVec4(0.0f, 1.0f, 0.0f, 1.0f), "Ectopic Beat");
			} 
			else if (SimulationSwitch.isInEctopicEventMode) 
			{
				ImGui::SameLine();
				ImGui::TextColored(ImVec4(0.0f, 1.0f, 0.0f, 1.0f), "Ectopic Trigger");
			} 
			else if (SimulationSwitch.isInAdjustMuscleAreaMode) 
			{
				ImGui::SameLine();
				ImGui::TextColored(ImVec4(0.0f, 1.0f, 0.0f, 1.0f), "Adjust Area");
			} 
			else if (SimulationSwitch.isInAdjustMuscleLineMode) 
			{
				ImGui::SameLine();
				ImGui::TextColored(ImVec4(0.0f, 1.0f, 0.0f, 1.0f), "Adjust Line");
			} 
			else if (SimulationSwitch.isInFindNodeMode) 
			{
				ImGui::SameLine();
				ImGui::TextColored(ImVec4(0.0f, 1.0f, 1.0f, 1.0f), "Identify Node");
			}
			else if (SimulationSwitch.isInFindMuscleMode)
			{
				ImGui::SameLine();
				ImGui::TextColored(ImVec4(0.0f, 1.0f, 0.0f, 1.0f), "Identify Muscle");
			}
			else //not in a mode
			{
				ImGui::SameLine();
				ImGui::TextColored(ImVec4(0.0f, 1.0f, 0.0f, 1.0f), "None");
			}

			// Mouse mode buttons
			if (ImGui::Button("Mouse Off"))
			{
				mouseFunctionsOff();
				SimulationSwitch.isInMouseFunctionMode = false;
			}
			if (ImGui::Button("Ablate Mode")) 
			{
				mouseAblateMode();
			}
			if (ImGui::Button("Ectopic Trigger")) 
			{
				mouseEctopicEventMode();
			}
			if (ImGui::Button("Ectopic Beat")) 
			{
				mouseEctopicBeatMode();
			}
			if (ImGui::Button("Adjust Area"))
			{
				mouseAdjustMusclesAreaModeMultiplier();
			}
			ImGui::SameLine();
			if (ImGui::Button("Adjust Line")) 
			{
				mouseAdjustMusclesLineModeMultiplier();
			}
			if (ImGui::Button("Identify Node")) 
			{
				mouseIdentifyNodeMode();
			}
			ImGui::SameLine();
			if (ImGui::Button("Identify Muscle")) 
			{
				mouseIdentifyMuscleMode();
			}

			// Display identified nodes in a window when in find node mode
			if (SimulationSwitch.isInFindNodeMode)
			{
				ShowIdentifiedNodesBox();
			}

			// Display identified muscles in a window when in find muscle mode
			if (SimulationSwitch.isInFindMuscleMode)
			{
				ShowIdentifiedMusclesBox();
			}

			//Muscle adjustments
			if (SimulationSwitch.isInAdjustMuscleAreaMode || SimulationSwitch.isInAdjustMuscleLineMode)
			{
				ImGui::Text("Refractory Period Multiplier");
				//Refactory Period Multiplier input box
				ImGui::SameLine();
				ImGui::SetNextItemWidth(60); // Fixed width for input box
				if (ImGui::InputFloat("##refractoryInput", &RefractoryPeriodAdjustmentMultiplier, 0, 0, "%.3f"))
				{
					// Clamp to valid range
					if(RefractoryPeriodAdjustmentMultiplier < 0.001f) RefractoryPeriodAdjustmentMultiplier = 0.001f;
					else if(20.0f < RefractoryPeriodAdjustmentMultiplier) RefractoryPeriodAdjustmentMultiplier = 20.0f;
				}

				//Conduction Velocity Multiplier input box
				ImGui::Text("Conduction Velocity Multiplier");
				ImGui::SameLine();
				ImGui::SetNextItemWidth(60); // Fixed width for input box
				if (ImGui::InputFloat("##CVInput", &MuscleConductionVelocityAdjustmentMultiplier, 0, 0, "%.3f"))
				{
					// Clamp to valid range
					if(MuscleConductionVelocityAdjustmentMultiplier < 0.001f) MuscleConductionVelocityAdjustmentMultiplier = 0.001f;
					else if(20.0f < MuscleConductionVelocityAdjustmentMultiplier) MuscleConductionVelocityAdjustmentMultiplier = 20.0f;
				}
			}
		}
    
		// Heartbeat controls
		if (ImGui::CollapsingHeader("Heartbeat Controls"))
		{
			ImGui::Text("Beat Period (ms)");
			ImGui::SameLine();

			//Input field for beat period of the Pulse Node
			ImGui::SetNextItemWidth(60);  // Make the input field smaller, fixed 60 pixels
			if (ImGui::InputFloat("##beatPeriodInput", &Node[PulsePointNode].beatPeriod, 0, 0, "%.1f")) 
			{
				// Clamp to valid range
				if(Node[PulsePointNode].beatPeriod < 5.0f) Node[PulsePointNode].beatPeriod = 5.0f;
				else if(2000.0f < Node[PulsePointNode].beatPeriod) Node[PulsePointNode].beatPeriod = 2000.0f;
				cudaMemcpy(NodeGPU, Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice);
				cudaErrorCheck(__FILE__, __LINE__);
					
			}
       
			ImGui::Separator();
			ImGui::Text("Ectopic Beats");

			// Show each ectopic beat node
			bool hasEctopicBeats = false; // flag to see if we have any ectopic beats; consider adding to simulation struct?
			for(int i = 0; i < NumberOfNodes; i++) 
			{
	    			if(Node[i].isBeatNode && i != PulsePointNode) //if this is an ectopic beat node and not the pulse node
				{
					hasEctopicBeats = true;
		
					char nodeName[32];
					sprintf(nodeName, "Ectopic Beat Node %d", i);
		
					if (ImGui::TreeNode(nodeName))  //a tree node is a collapsible section, so we can have multiple ectopic beats in the same window
					{
						ImGui::Text("Ectopic Beat Period (ms)");
						ImGui::SameLine();
						ImGui::SetNextItemWidth(60); // Fixed width for input box
						// Input field for ectopic beat period
						if (ImGui::InputFloat("##beatPeriodInput", &Node[i].beatPeriod, 0, 0, "%.1f"))
						{
							// Clamp to valid range
							if(Node[i].beatPeriod < 5.0f) Node[i].beatPeriod = 5.0f;
							else if(2000.0f < Node[i].beatPeriod) Node[i].beatPeriod = 2000.0f;
							cudaMemcpy(NodeGPU, Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice);
							cudaErrorCheck(__FILE__, __LINE__);
						}

						ImGui::Text("Time Until Next Beat (ms)");
						float timeDelay = Node[i].beatPeriod - Node[i].beatTimer;
						ImGui::SameLine();
						ImGui::SetNextItemWidth(60);
						// Input field for ectopic beat delay
						if (ImGui::InputFloat("##timeDelayInput", &timeDelay, 0, 0, "%.1f"))
						{
							// Clamp to valid range
							timeDelay = (timeDelay < 0.0f) ? 0.0f : (timeDelay > Node[i].beatPeriod ? Node[i].beatPeriod : timeDelay);
							if(timeDelay < 0.0f) timeDelay = 0.0f;
							else if(Node[i].beatPeriod < timeDelay) timeDelay = Node[i].beatPeriod;
							
							Node[i].beatTimer = Node[i].beatPeriod - timeDelay;
							cudaMemcpy(NodeGPU, Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice);
							cudaErrorCheck(__FILE__, __LINE__);
						}
		    
						//button to remove ectopic beat nodes
		    				if (ImGui::Button("Delete Ectopic Beat")) 
						{
							Node[i].isBeatNode = false;
							Node[i].isDrawNode = false;
							Node[i].color = {0.0f, 1.0f, 0.0f, 1.0f}; // Reset color
							cudaMemcpy(NodeGPU, Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice);
							cudaErrorCheck(__FILE__, __LINE__);
						}
		    
		    				ImGui::TreePop(); // Close the tree node
					}
				}
			}
        
			if (!hasEctopicBeats) //if there are no ectopic beats, show a message
			{
				ImGui::TextDisabled("No ectopic beats configured."); //TextDisabled makes it greyed out
			}
		}

		// Utility functions
		if (ImGui::CollapsingHeader("Utilities"))
		{
			//Save run button
			if (ImGui::Button("Save Run"))
			{
			    saveRun();
			}
			ShowTooltip("(Ctrl + Shift + S)\nSave current muscle properties and simulation\nsettings to a file for later use");
		}

		//Display movement controls
		if (ImGui::CollapsingHeader("Keyboard Controls"))
		{
			ImGui::Text("Quit: esc");
			ImGui::NewLine();
			ImGui::Text("Translate Left/Right: x/X");
			ImGui::Text("Translate Up/Down:    y/Y");
			ImGui::Text("Translate In/Out:     z/Z");
			ImGui::NewLine();
			ImGui::Text("Rotate X-axis: Ctrl x/X");
			ImGui::Text("Rotate Y-axis: Ctrl y/Y");
			ImGui::Text("Rotate Z-axis: Ctrl z/Z");
			ImGui::NewLine();
			ImGui::Text("Selection Sphere Size Adjustment: Ctrl ScrollWhell");
			ImGui::NewLine();
			ImGui::Text("Toggle GUI/Mouse mode: Tab");		
			ImGui::NewLine();
			ImGui::Text("Left Mouse: Change.");
			ImGui::Text("Right Mouse: Revert.");
			ImGui::Text("Middle Mouse: Toggles scroll speed.");
		}
	ImGui::End(); //end the main controls window
    
	// Beginning of stats window
	//if there's any relevant information we should show for quick viewing, put it here., we can add toggles for what to show in the main window if we want to.

	//Offset stats window by 10px from top-left edges. anchor to top left corner
	ImGui::SetNextWindowPos(ImVec2(viewport->WorkPos.x + 10, viewport->WorkPos.y + 10),ImGuiCond_Always,ImVec2(0.0f, 0.0f));
	
	// Create a new window for simulation stats, args are window name, NULL for no specific flags, and window_flags to set the window flags
	ImGui::Begin("Simulation Stats", NULL, window_flags); 

		// Show current mouse mode if in mouse mode
		if (SimulationSwitch.isInMouseFunctionMode)
		{
			const char* mode = NULL;
			ImVec4 color = ImVec4(1,1,1,1);
			if (SimulationSwitch.isInAblateMode) { mode = "Ablate"; color = ImVec4(1,0,0,1); }
			else if (SimulationSwitch.isInEctopicBeatMode) { mode = "Ectopic Beat"; color = ImVec4(0,1,0,1); }
			else if (SimulationSwitch.isInEctopicEventMode) { mode = "Ectopic Trigger"; color = ImVec4(0,0.5f,1,1); }
			else if (SimulationSwitch.isInAdjustMuscleAreaMode) { mode = "Adjust Area Mult"; color = ImVec4(1,1,0,1); }
			else if (SimulationSwitch.isInAdjustMuscleLineMode) { mode = "Adjust Line Mult"; color = ImVec4(1,0.5f,0,1); }
			else if (SimulationSwitch.isInFindNodeMode) { mode = "Identify Node"; color = ImVec4(0.5f,0,1,1); }
			else if (SimulationSwitch.isInFindMuscleMode) { mode = "Identify Muscle"; color = ImVec4(0,0.3f,1,1); }
			if (mode) ImGui::TextColored(color, "Mouse Mode: %s", mode);
			else ImGui::Text("Mouse Mode: None");
		}

		//
		if(!SimulationSwitch.isInMouseFunctionMode)
		{
			ImGui::Text("H to expand/collapse controls GUI");
			ImGui::Text("Tab to toggle mouse/GUI mode");
		}
		else
		{
			ImGui::Text("Tab to toggle mouse/GUI mode");
		}

		//Shows run time of the simulation and beat rate of the pulse node
		ImGui::Text("Run time: %.2f ms", RunTime);
		ImGui::Text("Beat rate: %.2f ms", Node[PulsePointNode].beatPeriod);

		//shows our current refractory period and conduction velocity multipliers
		if(SimulationSwitch.isInAdjustMuscleAreaMode || SimulationSwitch.isInAdjustMuscleLineMode) 
		{
			ImGui::Separator();
			ImGui::Text("Refractory multiplier: %.3f", RefractoryPeriodAdjustmentMultiplier);
			ImGui::Text("Conduction multiplier: %.3f", MuscleConductionVelocityAdjustmentMultiplier);
		}
		// Print ectopic beat nodes and their periods
		ImGui::Separator();
		for(int i = 0; i < NumberOfNodes; i++) 
		{
			if(Node[i].isBeatNode && i != PulsePointNode) 
			{
				ImGui::Text("Ectopic Beat Node %d: %.2f ms", i, Node[i].beatPeriod);
			}
		}
	ImGui::End(); //end of stats window 
}
