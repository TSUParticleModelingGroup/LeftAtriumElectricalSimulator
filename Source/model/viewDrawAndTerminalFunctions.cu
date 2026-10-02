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

/*
void showMuscleTypes()
{
	// If the binary file included node section colors, apply them back onto visible tissue nodes.
	if(BinaryNodeColors != NULL)
	{
		for(int i = 0; i < NumberOfNodes; i++)
		{
			// Do not overwrite special marker colors (ablation, adjust/find markers, etc.).
			if(!Node[i].isAblated && !Node[i].isDrawNode)
			{
				// Restore the node color that was saved in the binary export.
				Node[i].color = BinaryNodeColors[i];
			}
		}
	}

	// If the binary file included muscle section colors, restore those too.
	if(BinaryMuscleColors != NULL)
	{
		for(int i = 0; i < NumberOfMuscles; i++)
		{
			// Restore the muscle color that was saved in the binary export.
			Muscle[i].color = BinaryMuscleColors[i];
		}
	}

	copyNodesMusclesToGPU();
}
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
	Simulation.ViewFlag = 1;
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
	
	//if(!Simulation.isPaused) glColor3d(0.0,1.0,0.0); // Green is running
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
	if(Simulation.DrawNodesFlag == 1 || Simulation.DrawNodesFlag == 2)  //if we're drawing half(1) or all(2) of the nodes
	{
		for(int i = 0; i < NumberOfNodes; i++) // Start at 1 to skip the pulse node and go through all nodes
		{
			if(Simulation.DrawFrontHalfFlag == 1 || Simulation.DrawNodesFlag == 1) //If we're only drawing the nodes on the front half.
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
			if(Simulation.DrawFrontHalfFlag == 1)
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
				
				if(Simulation.DrawFrontHalfFlag == 1)
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
	
	// Mogy
// Just stuck this in to track the Action Potintial it will need cleaning up
// It does all muscle and is not turned off if you are only looking at the front half.
// It has not on off button in the simulationSwitchesStructure or a button on the GUI.
// Start ******************
	
	Simulation.isDrawAP = 1;
	float distance;
	float x,y,z,dx,dy,dz,d;
	int id1, id2;
	glColor3d(0.0, 0.0, 1.0);
	glPointSize(5.0);
	glBegin(GL_POINTS);
	if(Simulation.isDrawAP)
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
	if(Simulation.isInMouseFunctionMode)
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
	if(Simulation.isRecording)
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
	if(Simulation.isInMouseFunctionMode) Simulation.guiCollapsed = true;
	
	ImGui::SetNextWindowCollapsed(Simulation.guiCollapsed, ImGuiCond_Always);

    // Main Controls Window
    ImGui::Begin("Control Panel", NULL, window_flags); //title of the window, NULL means no pointer to a bool to close the window, window_flags are the flags we set above
    
	//update bool to match current state (makes sure clicking also works in addition to ctrl + h)
	Simulation.guiCollapsed = ImGui::IsWindowCollapsed();

    // Run/Pause button
    if (ImGui::Button(Simulation.isPaused ? "Run" : "Pause")) //print whats happening
    {
        Simulation.isPaused = !Simulation.isPaused;
    }
	ShowTooltip("(F1) or r/R");
    
    // General simulation controls
    if (ImGui::CollapsingHeader("Simulation Controls", ImGuiTreeNodeFlags_DefaultOpen)) //open by default
    {
        // View controls
        bool frontHalf = Simulation.DrawFrontHalfFlag == 1; //Needed because ImGui needs a bool for a checkbox, can make a dropbox if more display options are needed
        if(ImGui::Checkbox("Draw Front Half Only", &frontHalf)) //checkbox for if we only want to draw the first half of the nodes
        {
			//when the button is pressed it will change the value of frontHalf to the opposite of what it was before
            Simulation.DrawFrontHalfFlag = frontHalf ? 1 : 0;
            drawPicture();
        }
		ShowTooltip("(F2)");
        
        // Node display options
        const char* nodeOptions[] = { "Off", "Half", "Full" }; //array of options for the dropdown menu
        int nodeDisplay = Simulation.DrawNodesFlag;

		//Combo makes a dropdown menu with the options in the array
        if(ImGui::Combo("Show Nodes", &nodeDisplay, nodeOptions, 3)) //args are menu name, pointer to the selected option, array of text options, # of options
        {
            if (nodeDisplay != Simulation.DrawNodesFlag) // Only update if the value changes
            {
                Simulation.DrawNodesFlag = nodeDisplay;
                drawPicture();
            }
        }
		ShowTooltip("(F3)");
        
        // Button for recording
		if (ImGui::Button(Simulation.isRecording ? "Stop Recording" : "Record Video"))
		{
			if (Simulation.isRecording)
			{
				movieOff();
			}
			else
			{
				movieOn();
			}
		}
		ShowTooltip("(F4)");

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
		ShowTooltip("(F5)");
	}

	//Draw Rate Slider
	ImGui::Separator();
	ImGui::Text("Simulation Speed");
	if (ImGui::SliderInt("##DrawRateSlider", &DrawRate, 100, 5000, "%d")) //slider for setting the simulation rate
	{
		//bound slider values
		if (DrawRate < 1) DrawRate = 1;
		if (DrawRate > 5000) DrawRate = 5000;
	}
	ShowTooltip("(Shift + -/=)\nAdjust the speed of the simulation.\nHigher values are faster.\n\nSlider: 100 to 5000\nInput Box: 100 to 5000");
	//Input box for simulation speed
	if (ImGui::InputInt("##DrawRateinput", &DrawRate, 50, 100)) //input box for setting the simulation rate
	{
		//bound input values
		if (DrawRate < 100) DrawRate = 100;
		if (DrawRate > 5000) DrawRate = 5000;
	}
    
	// Mouse mode selection
	if (ImGui::CollapsingHeader("Mouse Functions", ImGuiTreeNodeFlags_DefaultOpen))
	{
		// Display current mouse mode
		ImGui::Text("Current Mode: ");

		if (Simulation.isInAblateMode) 
		{
			ImGui::SameLine();
			ImGui::TextColored(ImVec4(1.0f, 0.0f, 0.0f, 1.0f), "Ablate Mode");
			ImGui::Text("Tab to exit mouse mode");
			ImGui::Text("(Left Click: Ablate, Right Click: Undo)");
		}
		else if (Simulation.isInEctopicBeatMode) 
		{
			ImGui::SameLine();
			ImGui::TextColored(ImVec4(0.0f, 1.0f, 0.0f, 1.0f), "Ectopic Beat");
			ImGui::Text("Tab to exit mouse mode");
		} 
		else if (Simulation.isInEctopicEventMode) 
		{
			ImGui::SameLine();
			ImGui::TextColored(ImVec4(0.0f, 0.5f, 1.0f, 1.0f), "Ectopic Trigger");
			ImGui::Text("Tab to exit mouse mode");
		} 
		else if (Simulation.isInAdjustMuscleAreaMode) 
		{
			ImGui::SameLine();
			ImGui::TextColored(ImVec4(1.0f, 1.0f, 0.0f, 1.0f), "Adjust Area");
			ImGui::Text("Tab to exit mouse mode");
		} 
		else if (Simulation.isInAdjustMuscleLineMode) 
		{
			ImGui::SameLine();
			ImGui::TextColored(ImVec4(1.0f, 0.5f, 0.0f, 1.0f), "Adjust Line");
			ImGui::Text("Tab to exit mouse mode");
		} 
		else if (Simulation.isInFindNodeMode) 
		{
			ImGui::SameLine();
			ImGui::TextColored(ImVec4(0.5f, 0.0f, 1.0f, 1.0f), "Identify Node");
			ImGui::Text("Tab to exit mouse mode");
		}
		else if (Simulation.isInFindMuscleMode)
		{
			ImGui::SameLine();
			ImGui::TextColored(ImVec4(0.0f, 0.3f, 1.0f, 1.0f), "Identify Muscle");
			ImGui::Text("Tab to exit mouse mode");
		}
		else //not in a mode
		{
			ImGui::SameLine();
			ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.5f, 1.0f), "None");
			ImGui::Text("No mouse function mode active");
		}

		// Mouse mode buttons
		if (ImGui::Button("Mouse Off"))
		{
			mouseFunctionsOff();
			Simulation.isInMouseFunctionMode = false;
		}
		ShowTooltip("(Tab)\nDisables all mouse interaction with the model");

		if (ImGui::Button("Ablate Mode")) 
		{
			mouseAblateMode();
		}
		ShowTooltip("(F6)\nLeft-click to ablate nodes\nRight-click to undo ablation");

		if (ImGui::Button("Adjust Area"))
		{
			mouseAdjustMusclesAreaModeMultiplier();
		}
		ShowTooltip("(F7)\nLeft-click to adjust muscle properties in an area\nAffects refractory period and conduction velocity\n\nRight-click to undo adjustment");

		if (ImGui::Button("Adjust Line")) 
		{
			mouseAdjustMusclesLineModeMultiplier();
		}
		ShowTooltip("(Shift + F7)\nLeft-click to adjust muscle properties along a line\nAffects refractory period and conduction velocity\n\nRight-click to undo adjustment");

		if (ImGui::Button("Ectopic Trigger")) 
		{
			mouseEctopicEventMode();
		}
		ShowTooltip("(F8)\nLeft-click to trigger a single pulse at a node");

		if (ImGui::Button("Ectopic Beat")) 
		{
			mouseEctopicBeatMode();
		}
		ShowTooltip("(Shift + F8)\nLeft-click to set a node as an ectopic beat node\nwith a constant beat period");

		if (ImGui::Button("Identify Muscle")) 
		{
			mouseIdentifyMuscleMode();
		}
		ShowTooltip("(F9)\nLeft-click to display the conduction velocity \nand refractory period multipliers of a muscle");

		ImGui::SameLine();

		if (ImGui::Button("Identify Node")) 
		{
			mouseIdentifyNodeMode();
		}
		ShowTooltip("(Shift + F9)\nLeft-click to display the ID of a node");

		// Display identified nodes in a window when in find node mode
		if (Simulation.isInFindNodeMode)
		{
			ShowIdentifiedNodesBox();
		}

		// Display identified muscles in a window when in find muscle mode
		if (Simulation.isInFindMuscleMode)
		{
			ShowIdentifiedMusclesBox();
		}

		// Selection area slider
		float hitMult = HitMultiplier;
		if (ImGui::SliderFloat("Selection Area", &hitMult, 0.0f, 0.2f, "%.3f", ImGuiSliderFlags_AlwaysClamp))
		{
			HitMultiplier = hitMult;
		}
		ShowTooltip("(-/=): decrease/increase selection area\nAdjusts the size of the selection area\nLarger values affect more nodes");

		//Muscle adjustment sliders; shows when in adjust line or adjust area mode
		if (Simulation.isInAdjustMuscleAreaMode || Simulation.isInAdjustMuscleLineMode)
		{
			ImGui::Separator(); //add a line to separate the sections
			ImGui::Text("Muscle Adjustment Parameters");
			ImGui::NewLine(); //add a new line for spacing
			
			//refractory period slider
			ImGui::Text("Refractory Period Multiplier");
			float refractoryMultiplier = RefractoryPeriodAdjustmentMultiplier;
			ImGui::SetNextItemWidth(150); // Narrower slider to make room for input
			if (ImGui::SliderFloat("##refractoryMultiplier", &refractoryMultiplier, 0.001f, 20.0f, "%.3f")) 
			{
				RefractoryPeriodAdjustmentMultiplier = refractoryMultiplier;
			}
			ShowTooltip("Adjusts the refractory period of the muscle\n\nDrag the slider or enter a precise value in the input box");

			//refactory period input box
			ImGui::SameLine();
			ImGui::SetNextItemWidth(60); // Fixed width for input box
			float originalRefMultiplier = refractoryMultiplier;
			if (ImGui::InputFloat("##refractoryInput", &refractoryMultiplier, 0, 0, "%.3f"))
			{
				// Clamp to valid range
				refractoryMultiplier = (refractoryMultiplier < 0.001f) ? 0.001f : (refractoryMultiplier > 20.0f ? 20.0f : refractoryMultiplier);
				
				// Update if changed
				if (refractoryMultiplier != originalRefMultiplier)
				{
					RefractoryPeriodAdjustmentMultiplier = refractoryMultiplier;
				}
			}
			
			//reset button for refractory period multiplier
			ImGui::SameLine();
			if (ImGui::Button("Reset##1")) 
			{
				RefractoryPeriodAdjustmentMultiplier = 1.0f;
			}

			// For the Conduction Velocity Multiplier slider:
			ImGui::Text("Conduction Velocity Multiplier");
			float conductionMultiplier = MuscleConductionVelocityAdjustmentMultiplier;
			ImGui::SetNextItemWidth(150); // Narrower slider to make room for input
			if (ImGui::SliderFloat("##conductionVelocityMultiplier", &conductionMultiplier, 0.001f, 20.0f, "%.3f")) 
			{
				MuscleConductionVelocityAdjustmentMultiplier = conductionMultiplier;
			}
			ShowTooltip("Adjusts the refractory period of the muscle\n\nDrag the slider or enter a precise value in the input box");

			ImGui::SameLine();

			// For the Conduction Velocity Multiplier input box:
			ImGui::SetNextItemWidth(60); // Fixed width for input box
			float originalConductionMultiplier = conductionMultiplier;
			if (ImGui::InputFloat("##conductionInput", &conductionMultiplier, 0, 0, "%.3f"))
			{
				// Clamp to valid range
				conductionMultiplier = (conductionMultiplier < 0.001f) ? 0.001f : (conductionMultiplier > 20.0f ? 20.0f : conductionMultiplier);
				
				// Update if changed
				if (conductionMultiplier != originalConductionMultiplier)
				{
					MuscleConductionVelocityAdjustmentMultiplier = conductionMultiplier;
				}
			}
			
			//reset button for conduction velocity multiplier
			ImGui::SameLine();
			if (ImGui::Button("Reset##2"))
			{
				MuscleConductionVelocityAdjustmentMultiplier = 1.0f;
			}
		}
	}
    
    // Heartbeat controls
    if (ImGui::CollapsingHeader("Heartbeat Controls"))
    {
		//Slider for beat period of the Pulse Node
		ImGui::Text("Beat Period (ms)");
        	float beatPeriod = Node[PulsePointNode].beatPeriod;
		float beatPeriodMin = 10.0f; // Minimum value for beat period
		float beatPeriodMax = 1000.0f; // Maximum value for beat period

        if (ImGui::SliderFloat("##beatPeriodSlider", &beatPeriod, beatPeriodMin, beatPeriodMax, "%.1f ms")) 
		{
            Node[PulsePointNode].beatPeriod = beatPeriod;
            cudaMemcpy(NodeGPU, Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice);
            cudaErrorCheck(__FILE__, __LINE__);
		}
		ShowTooltip("(Ctrl + -/=): decrease/increase\nAdjust period of time between beats from the pulse node\n\nDrag the slider or enter a precise value in the input box");

		ImGui::SameLine();

		//Input field for beat period of the Pulse Node
		ImGui::SetNextItemWidth(60);  // Make the input field smaller, fixed 60 pixels
		float originalBeatPeriod = beatPeriod; //Store the original value to check if it changed
		if (ImGui::InputFloat("##beatPeriodInput", &beatPeriod, 0, 0, "%.1f")) 
		{
			//make sure input is valid
			beatPeriod = (beatPeriod < beatPeriodMin) ? beatPeriodMin : (beatPeriod >  beatPeriodMax ?  beatPeriodMax : beatPeriod); //if the input is less than the min, set it to the min, if its greater than the max, set it to the max
			
			// If value actually changed, update
			if (beatPeriod != originalBeatPeriod) 
			{
				Node[PulsePointNode].beatPeriod = beatPeriod;
				cudaMemcpy(NodeGPU, Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice);
				cudaErrorCheck(__FILE__, __LINE__);
			}
		}
        
		//button to add 10ms to the beat period
        if (ImGui::Button("+ 10ms")) 
		{
            Node[PulsePointNode].beatPeriod += 10;
            cudaMemcpy(NodeGPU, Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice);
            cudaErrorCheck(__FILE__, __LINE__);
        }

        ImGui::SameLine();

		//button to subtract 10ms from the beat period
        if (ImGui::Button("- 10ms")) 
		{
            Node[PulsePointNode].beatPeriod -= 10;
            if(Node[PulsePointNode].beatPeriod < 0) // Prevent negative beat period 
			{
                Node[PulsePointNode].beatPeriod = 0;
            }
            cudaMemcpy(NodeGPU, Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice);
            cudaErrorCheck(__FILE__, __LINE__);
        }
        
        //Ectopic beat Sliders
        ImGui::Separator();
        ImGui::Text("Ectopic Beats");
        
        // Show sliders for each ectopic beat node
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
					ImGui::NewLine(); //add a new line for spacing

					ImGui::Text("Ectopic Beat Period (ms)");
					float beatPeriod = Node[i].beatPeriod;

					ImGui::SetNextItemWidth(150); // Narrower slider so the input box fits better

					// Slider for ectopic beat period
					if (ImGui::SliderFloat("##EctopicBeatPeriod", &beatPeriod, 10.0f, 1000.0f, "%.1f ms")) 
					{
						Node[i].beatPeriod = beatPeriod;
						cudaMemcpy(NodeGPU, Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice);
						cudaErrorCheck(__FILE__, __LINE__);
					}
					ShowTooltip("Controls how often this node beats\n\nDrag the slider or enter a precise value in the input box");

					ImGui::SameLine();


					ImGui::SetNextItemWidth(60); // Fixed width for input box

					// Input field for ectopic beat period
					float originalBeatPeriod = beatPeriod;
					if (ImGui::InputFloat("##beatPeriodInput", &beatPeriod, 0, 0, "%.1f"))
					{
						// Clamp to valid range
						beatPeriod = (beatPeriod < 10.0f) ? 10.0f : (beatPeriod > 1000.0f ? 1000.0f : beatPeriod);
						
						// Update if changed
						if (beatPeriod != originalBeatPeriod)
						{
							Node[i].beatPeriod = beatPeriod;
							cudaMemcpy(NodeGPU, Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice);
							cudaErrorCheck(__FILE__, __LINE__);
						}
					}

					// Delay/time until next beat slider for ectopic beats
					ImGui::Text("Time Until Next Beat (ms)");
					float timeDelay = Node[i].beatPeriod - Node[i].beatTimer;
					ImGui::SetNextItemWidth(150); // Narrower slider
					if (ImGui::SliderFloat("##ectopicBeatPeriodDelay", &timeDelay, 0.0f, Node[i].beatPeriod, "%.1f ms")) 
					{
						// Convert back to beatTimer when storing
						Node[i].beatTimer = Node[i].beatPeriod - timeDelay;
						cudaMemcpy(NodeGPU, Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice);
						cudaErrorCheck(__FILE__, __LINE__);
					}
					ShowTooltip("Controls how long until this node beats\n\nDrag the slider or enter a precise value in the input box");

					ImGui::SameLine();
					ImGui::SetNextItemWidth(60);

					// Input field for ectopic beat delay
					float originalTimeDelay = timeDelay;
					if (ImGui::InputFloat("##timeDelayInput", &timeDelay, 0, 0, "%.1f"))
					{
						// Clamp to valid range
						timeDelay = (timeDelay < 0.0f) ? 0.0f : (timeDelay > Node[i].beatPeriod ? Node[i].beatPeriod : timeDelay);
						
						// Update if changed
						if (timeDelay != originalTimeDelay)
						{
							Node[i].beatTimer = Node[i].beatPeriod - timeDelay;
							cudaMemcpy(NodeGPU, Node, NumberOfNodes*sizeof(nodeAttributesStructure), cudaMemcpyHostToDevice);
							cudaErrorCheck(__FILE__, __LINE__);
						}
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
            ImGui::Text("Use the Ectopic Beat button to add one.");
        }
    }
    
    // Utility functions
    if (ImGui::CollapsingHeader("Utilities"))
    {
		//Save settings button
        if (ImGui::Button("Save Settings"))
		{
            saveSettings();
        }
		ShowTooltip("(Ctrl + Shift + S)\nSave current muscle properties and simulation\nsettings to a file for later use");

		if (ImGui::Button("Show sections"))
		{
			Simulation.isPaused = true;
			// Apply saved section colors from the loaded binary data.
			//showMuscleTypes();
			// Redraw immediately so the section colors appear as soon as the button is pressed.
			drawPicture();
		}
		ShowTooltip("Shows the designated sections of the left atrium in different colors.");

        //Find nodes button - toggle to show/hide markers
        static bool markersShowing = false;
        if (ImGui::Button(markersShowing ? "Hide Pulse/Back/Top Nodes" : "Show Pulse/Back/Top"))
		{
            if (markersShowing)
            {
                hidePulseBackTopNodes();
                markersShowing = false;
            }
            else
            {
                findNodes();
                markersShowing = true;
            }
        }
		ShowTooltip("Toggle visibility of pulse/back/top node markers");

		// Display selected-node information.
		if (Simulation.nodesFound) 
		{
			ImGui::Separator();
			ImGui::Text("Pulse node (gold): %d", PulsePointNode);
			ImGui::Text("Back node (orange): %d", FrontNode);
			ImGui::Text("Top node (cyan): %d", UpNode);
		}

		if (ImGui::Button("Save State"))
		{
			saveState();
		}
		ShowTooltip("(Ctrl + S)\nSave the current state of the simulation, including all node properties and current simulation time\nThis is different from Save Settings, which only saves muscle properties and general settings");
		
		ImGui::SameLine();
		if (ImGui::Button("Load State"))
		{
			loadState();
		}
		ShowTooltip("(Ctrl + Z)\nLoad a previously saved state of the simulation\nThis will overwrite the current state with the saved one, including all node properties and current simulation time");
    }

	//Display movement controls
	if (ImGui::CollapsingHeader("Keyboard Controls"))
	{

		ImGui::Text("Quit: Shift + Esc");
		ImGui::NewLine(); //add a new line for spacing
		ImGui::Text("Rotate X-axis: a/d; Left/Right");
		ImGui::Text("Rotate Y-axis: w/s; Up/Down");
		ImGui::Text("Rotate Z-axis: z/Z; Shift + Left/Right");
		ImGui::Text("Zoom In/Out: e/E; Shift + Up/Down");
		ImGui::Text("Collapse/Expand GUI: h/H");
		ImGui::Text("Toggle Mouse/GUI Mode: Tab");
		
	}
    
    ImGui::End(); //end the main controls window
    
	// Beginning of stats window
	//if there's any relevant information we should show for quick viewing, put it here., we can add toggles for what to show in the main window if we want to.

	//Offset stats window by 10px from top-left edges. anchor to top left corner
	ImGui::SetNextWindowPos(ImVec2(viewport->WorkPos.x + 10, viewport->WorkPos.y + 10),ImGuiCond_Always,ImVec2(0.0f, 0.0f));

	ImGui::Begin("Simulation Stats", NULL, window_flags); // Create a new window for simulation stats, args are window name, NULL for no specific flags, and window_flags to set the window flags

	// Show current mouse mode if in mouse mode
	if (Simulation.isInMouseFunctionMode)
	{
		const char* mode = NULL;
		ImVec4 color = ImVec4(1,1,1,1);
		if (Simulation.isInAblateMode) { mode = "Ablate"; color = ImVec4(1,0,0,1); }
		else if (Simulation.isInEctopicBeatMode) { mode = "Ectopic Beat"; color = ImVec4(0,1,0,1); }
		else if (Simulation.isInEctopicEventMode) { mode = "Ectopic Trigger"; color = ImVec4(0,0.5f,1,1); }
		else if (Simulation.isInAdjustMuscleAreaMode) { mode = "Adjust Area Mult"; color = ImVec4(1,1,0,1); }
		else if (Simulation.isInAdjustMuscleLineMode) { mode = "Adjust Line Mult"; color = ImVec4(1,0.5f,0,1); }
		else if (Simulation.isInFindNodeMode) { mode = "Identify Node"; color = ImVec4(0.5f,0,1,1); }
		else if (Simulation.isInFindMuscleMode) { mode = "Identify Muscle"; color = ImVec4(0,0.3f,1,1); }
		if (mode)
			ImGui::TextColored(color, "Mouse Mode: %s", mode);
		else
			ImGui::Text("Mouse Mode: None");
	}

	//
	if(!Simulation.isInMouseFunctionMode)
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
	if(Simulation.isInAdjustMuscleAreaMode || Simulation.isInAdjustMuscleLineMode) 
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
