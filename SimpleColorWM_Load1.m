function SimpleColorWM_Load1

%this program is designed to tax visual working memory for simple color
%stimuli, toward the noble purpose of characterizing the functional
%contribution of the magical IPS capacity region

%the code can deliver blocks of 
%1) spatial change detection (wherein sample colors
%are selected from a consistent subset of the entire color space, and
%probes are either matching or non-matching tothe sample item at the probe
%location. Non-matching probes can be either novel colors or lures that
%were presented at a different location in the sample array
%2)continuous report precision (wherein the possible smple colors shift around the color 
%space to require higher resolution memory, and memory is probed by
%requiring selection of a specific shade from a color wheel) or 
%3) central, sequential change detection (like spatial change detection, but all colors
%are presented centrally, and probe is just for whether the item appeared
%at all in the sequence)

%%
%Things that should be specified at the outset:

    % need "ColorWM_Data" folder in same directory

    % "viewDist" & "cmScreenWidth" customize visual angle for your monitor setup
    
    % "BlockNum", "TrialNum" & "NumTasks" 
    
    % "Sizes" specifies what set sizes you want to deliver
    
    % "LoadLevel" vector should be adjusted depending on number of set sizes
    % you are administering (specified with "Sizes")
    
    % "NumChangeColors" needs to be at least one more than the maximum set size

%%
rng('default'); %sometimes, if you've recently initiated the legacy random number generator, it wont let you use rng until you reset it to default, or something
rng('shuffle');

KbName('UnifyKeyNames'); 
    
%message pops up in the command window to ask for subject number and current stimulation site   
subject = input('Enter SUBJECT number ', 's');
session = input('Enter SESSION number ', 's');
target = 'Pilot'; % input('Enter STIMULATION SITE ', 's');

%name of data output file 
datafilename = strcat('ColorWM_Data/SimpleColorWM_', subject,'_', session, '_',target, '_', '.txt'); 

%if a file with that same info already exists, lets you give a
%new subject #, or overwrite the existing file
if exist(datafilename)==2
    disp ('A file with this name already exists')
    overwrite = input('overwrite?, y/n \n', 's');
    if strcmpi(overwrite, 'n')
        %disp('enter new subject number');
        newsub = input('New SUBJECT number? ', 's');
        newsesh = input('New Session number? ', 's');
        newtarg = input('New Stimulation Site name? ', 's');
        datafilename = strcat('ColorWM_Data/SimpleColorWM_', newsub, '_', newsesh, '_', newtarg, '_', '.txt');
        %jms subject = str2double(newsub);
        %jms session = str2double(newsesh);
    end
end

%make a comma-delimited text output file where each trial is a row
fid = fopen(datafilename, 'w');
fprintf(fid, 'subject, session, target, StimLat, CurrentTask, TaskCondition, block, trial, LoadLevel, SetSize, ShownLocs, AllColors, ShownColors, ProbeMatch, ChosenProbeColor, CorrectProbeColor, ProbeLoc, probert, msecProbeRT, probeACC, response, error\n');
%do you have a preferred data output format? well, this is what I do, so
%shove it. j/k! should we make a struct or something?

%% Some PTB and Screen set-up  
AssertOpenGL;    
HideCursor;
%ListenChar(2);
KbCheck; 
WaitSecs(0.1);
GetSecs;
KeyBoardNum = GetKeyboardIndices; 

    Screen('Preference', 'SkipSyncTests',1); %change to 0 before running for real
    Screen('Preference', 'VBLTimestampingMode', 1);
    screenNumber=max(Screen('Screens')); %precision color wheel responses can get wonky if you don't use the main screen of a dual monitor setup
    %screenNumber=1; 
    
    %give values for screen elements
    screenColor = [128 128 128];
    fixColor = [255 255 255];
    fixColorTwo = [1 1 1]; % jms
    
    gray = GrayIndex(0);
    black = BlackIndex(0);
    
    ThickOutlineWidth = 6; %weight of box to mark the probe location for continuous report
    ThinOutlineWidth = 1; %lighter box to outline all other stim locations at probe
    
    [win, wRect]=Screen('OpenWindow',screenNumber, screenColor);
    
    priorityLevel=MaxPriority(win);
    Priority(priorityLevel);    
    
    Screen('TextSize', win, 36);
    Screen('TextFont', win, 'Arial');
    Screen('TextColor', win, fixColor);
    
    Screen('BlendFunction', win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA'); %we probably don't actually need this for this task
    
    %determine center of screen from which to determine size and location
    %of stimuli
    centerX = wRect(3)/2;
    centerY = wRect(4)/2; 

    [screenXpixels, screenYpixels] = Screen('WindowSize', win);
    Xcenter = screenXpixels/2;%i'm not totally sure why have this as well as the one above, but I think there's a reason
    Ycenter = screenYpixels/2;    
    
    
%% Specify timing and condition values
    
    %set timings for different task events
    ITI = 1;
    StimShow = .5;
    WMdelay = 1;
    CentralStimShow = .1; % jms: .25 or .5
    CentralDelay = .066; % jms
    ChangeProbe = 2;
    responseDeadline = 4;
    
    %set #of blocks and trials and set sizes
    BlockNum = 2; %should be a multiple of whatever number of task conditions are being administered (if you want equal numbers of each)
    TrialNum = 9; %should be a mulitple of whatever number of set size conditions are administered
    NumTasks = 2; %# of task conditions you're testing here, used later to calculate # of blocks per task
    %(i.e., there are 3 possible tasks in here, but maybe you're only using 2 at once or whatever)    
    
    % Select what task to run, so you don't always have to be searching
    % through the script and trying to figure out which code to use when
    % you only want to run precision
    
    % 1 = spatial change detection
    % 2 = precision
    % 3 = central change detection
    % 4 = ALL, equally mixed    
    TaskChooser = 4;
    
    %indicate what set sizes you want to deliver
    Sizes = [1 3 5];%adjust LoadLevel vector for # of levels you put here
    % FYI, if you want a condition with set size of 1, you need to adjust the
    % "ProbeConditions" vector to exclude lures
    maxSetSize = max(Sizes);
    NumLevels = length(Sizes);    
    
    %change detection response keys
    matchResp = 's';
    nonmatchResp = 'd';
    
    WheelRespKey = KbName('r');
    
    NumChangeColors = 8; %how many equally spaced colors will be selected for change detection blocks--should be at least one more than max set size
    
    waitFrames = 1;
    ifi = Screen('GetFlipInterval', win);    
    
%% Specify types of task blocks that will be delivered 
    
    %make and randomize a vector of ones and twos from which to harvest the task condition
    %include threes if you want centrally, sequentially presented stims
    BlocksPer = BlockNum/NumTasks;
    BlocksPer = ceil(BlocksPer);
    Task = [ones(1, BlocksPer) 2*ones(1, BlocksPer)];
    %Task = [ones(1, BlocksPer) 2*ones(1, BlocksPer) 3*ones(1, BlocksPer)]; %1=Spatial change detection; 2=Continuous report; 3=Central, sequential
    Task = Shuffle(Task);
    
%% Stim size and location stuff

    %Adjust for current set-up!!!
    viewDist = 60; % dist in cm from subject to screen
    cmScreenWidth = 27.5; % width of the screen

    %Define the size of each sample stimulus
    stimAngleSize = .5; %in visual angle
    stimPixelSize = angle2pix(viewDist, cmScreenWidth, screenXpixels, stimAngleSize);
    
    %make the outlined probe box slightly bigger than the stimRect, just cause the thicker
    %outline creates the illusion that's it's smaller than the other boxes
    probeAngleSize = .6;
    probePixelSize = angle2pix(viewDist, cmScreenWidth, screenXpixels, probeAngleSize);
    
    %Define the radius of the circle around which stims are displayed
    stimEccAngle = 3; %in visual angle
    stimEccPixel = angle2pix(viewDist, cmScreenWidth, screenXpixels, stimEccAngle);
    
    %define base stimulus rect, whch will then be moved around according to current conditions 
    stimRect = [centerX centerY centerX+stimPixelSize centerY+stimPixelSize];
    CenterStim = CenterRectOnPointd(stimRect, Xcenter, Ycenter);
    
    probeRect = [centerX centerY centerX+probePixelSize centerY+probePixelSize];

    %Define the fixation rect
    fixHalfAngle = 0.1; %in visual angle

    fixHalfPixel = angle2pix(viewDist, cmScreenWidth, screenXpixels, ...
                                    fixHalfAngle);
    fixRect = [Xcenter - fixHalfPixel ...
                       Ycenter - fixHalfPixel ...
                       Xcenter + fixHalfPixel ...
                       Ycenter + fixHalfPixel]; 
    
    %make box in which to accept clicks for entering color wheel responses
    respBoxRectDim = fixHalfPixel*4;
    
    clickRespX1 = Xcenter - respBoxRectDim;
    clickRespY1 = Ycenter - respBoxRectDim;
    clickRespX2 = Xcenter + respBoxRectDim;
    clickRespY2 = Ycenter + respBoxRectDim;    
    
    respBoxRect = [clickRespX1 clickRespY1 clickRespX2 clickRespY2];

    
    %make an invisible box aroud the response box, so nearby clicks dont change the color choice    
    respBoxRangeDim = fixHalfPixel*30; %this is an arbitrary buffer box size
    
    fixRespX1 = Xcenter - respBoxRangeDim;
    fixRespY1 = Ycenter - respBoxRangeDim;
    fixRespX2 = Xcenter + respBoxRangeDim;
    fixRespY2 = Ycenter + respBoxRangeDim;
       
    
    %stims can be displayed either all on the right, all on the left, or
    %all around
    Laterality = 2;
    
    switch Laterality
        case 1
            StimLat = 'Right';
            LocationRange = 180;
            adder = 2; %adder is used later so we divide the space by enough that no stims fall on the midline
            sideswitcher = -90;
            start = 2; %and then we start from the second location, cause the first one is on the midline
            last = 1;
        case 2
            StimLat = 'Left';
            LocationRange = 180;
            adder = 2;
            sideswitcher = 90;
            start = 2;
            last = 1;
        case 3
            StimLat = 'Bilateral';
            LocationRange = ceil(360-(360/maxSetSize));
            adder = 0;
            sideswitcher = 0;
            start = 1;
            last = 0;
    end
     
        %identify equidistant angles around a circle, depending on current display area and max set size        
        SampleSpots = linspace(0, LocationRange, maxSetSize+adder);
        SampleSpots = (SampleSpots)+sideswitcher;
        SampleSpots = SampleSpots(start:maxSetSize+last);
        SampleSpots = degtorad(SampleSpots);
        
        circleX = zeros(maxSetSize, 1);
        circleY = zeros(maxSetSize, 1);
        
        %define polar coordinates for all the possible locations (given the
        %current max set size)
        for SampleLoc = 1:maxSetSize                
            circleX(SampleLoc) = stimEccPixel*cos(SampleSpots(SampleLoc))+Xcenter;
            circleY(SampleLoc) = stimEccPixel*sin(SampleSpots(SampleLoc))+Ycenter;
        end             
        
%% Color-choosing stuff

    %choose total number of colors(NumH), and give saturation and brightness values for HSV space
    NumH = 360;
    S = .6; %saturation, this should be between 0 and 1
    V = .9; %value (roughly, brightness), also between 0 and 1
    
    %little function I appended to script, where you first define the
    %range of color space you want, using HSV (above), then convert to RGB
    [rgb_values] = RGBwheel_fromHSV(NumH, S, V);
    
    %divy up the color space    
    NumColors = length(rgb_values);
    
    %divide the available colors evenly by the number of colors we want for change detection
    ChangeColorRange = NumColors/NumChangeColors;
    ChangeColors = linspace(1, NumColors-ChangeColorRange, NumChangeColors);
    ChangeColors = ceil(ChangeColors);

    %here, WheelColors is defined the same way as ChangeColors, then later
    %rotated around the color space for each continuous report trial
    WheelColors = ChangeColors;
    colorRotater = (floor(ChangeColorRange))-1;
    colorRotater = (0:colorRotater); %this is the range over which the chosen colors can shift on each trial
    
    %% Define the color wheel for continuous probes
    
    innerWheelDegree = 4; %needs to be bigger than stimEccAngle so it doesn't overlap with probe display
    outerWheelDegree = 5;
    innerWheelPixel = angle2pix(viewDist, cmScreenWidth, screenXpixels, innerWheelDegree);
    outerWheelPixel = angle2pix(viewDist, cmScreenWidth, screenXpixels, outerWheelDegree);
    colorWheel = [Xcenter - outerWheelPixel Ycenter - outerWheelPixel ...
                   Xcenter + outerWheelPixel Ycenter + outerWheelPixel];
    wheelCenter = [Xcenter - innerWheelPixel Ycenter - innerWheelPixel ...
                    Xcenter + innerWheelPixel Ycenter + innerWheelPixel];   

    
    %% Start task block loop
    
    welcome=sprintf('Press space to begin the experiment \n \n \n');
    DrawFormattedText(win, welcome, 'center', 'center', 0);
    Screen('Flip', win);
   
    % Wait for a key press using the custom getkey function
    if IsOSX
    getKey('space', KeyBoardNum); %OSX requires a device number whereas windows requires none
    else
        getKey('space');
    end
    
    
    for block = 1:BlockNum         
    
        %make and randomize a vector the length of the trialNum, composed of 
        %equal numbers of each load level
        TrialsPer = TrialNum/NumLevels; 
        TrialsPer = ceil(TrialsPer); %round up in case the # of trials can't be evenly divided
        LoadLevel = [ones(1, TrialsPer) 2*ones(1, TrialsPer) 3*ones(1, TrialsPer)];
        %LoadLevel = [ones(1, TrialsPer) 2*ones(1, TrialsPer) 3*ones(1, TrialsPer) 4*ones(1, TrialsPer) 5*ones(1, TrialsPer)];
        LoadLevel = Shuffle(LoadLevel);                
        
        %if you only wanna run a particular condition, specify that with
        %TaskChooser up top
        if TaskChooser == 4
            CurrentTask = Task(block);
        else
            CurrentTask = TaskChooser;
        end

        
        switch CurrentTask
            
            case 1 %regular change detection (multiple locations presented simultaneously)
                
                TaskCondition = 'SpatialChangeDetection';
                                
                instruct=sprintf('Spatial Change Detection \n\n\n\n Use S and D to indicate same or different\n\n for color of stimulus at probed location\n\n\n\nRemember to fixate on the center white square\n\nwhenever it is on the screen\n\n\n\nPress SPACE');                
                
                ProbeType = 1;
                
                %half of non-match probes should be a randomly selected
                %lure, the other half randomly selected from one of the
                %remaining colors that wasn't shown on that trial
                MatchNum = TrialNum/2;
                MatchNum = ceil(MatchNum);
                NonMatchNum = TrialNum/4;
                NonMatchNum = ceil(NonMatchNum); %round up in case the number of trials can't be evenly divided
                ProbeConditions=[ones(1, MatchNum) 2*ones(1, NonMatchNum) 3*ones(1, NonMatchNum)];               
                ProbeConditions = Shuffle(ProbeConditions);
                
            case 2 %continuous report
                
                TaskCondition = 'Precision';
                
                instruct=sprintf('Precision \n\n\n\nClick around the wheel to find the right color\n\nThen press R to enter response\n\n\n\nRemember to fixate on the center white square\n\nwhenever it is on the screen\n\n\n\nPress SPACE'); %would we rather use keyboard input? or a response dial?   
 
                ProbeType = 2;
                
            case 3 %central, sequential presentation    
                                
                TaskCondition = 'CentralChangeDetection';
                
                instruct=sprintf('Central Change Detection \n\n\n\n Use S and D to indicate same or different\n\n for whether color was in the sample set\n\n\n\n\nPress SPACE');%should change detection and precision blocks use the same kind of response input?
                
                ProbeType = 3;
                
                %half of probes were in the sample series, the other half
                %are novel
                MatchNum = TrialNum/2;
                MatchNum = ceil(MatchNum);
                NonMatchNum = TrialNum/2;
                NonMatchNum = ceil(NonMatchNum);
                ProbeConditions=[ones(1, MatchNum) 2*ones(1, NonMatchNum)];               
                ProbeConditions = Shuffle(ProbeConditions);                
        end
        
            DrawFormattedText(win, instruct, 'center', 'center', 0);
            Screen('Flip', win);
            
            if IsOSX
            getKey('space', KeyBoardNum);
            else
                getKey('space');
            end
    
    
    for trial = 1:TrialNum
        
            Screen('FillRect', win, fixColor, fixRect);       
            Screen('Flip', win);
            WaitSecs(ITI);
                        
            CurrentSetSize = LoadLevel(trial);  
            SetSize = Sizes(CurrentSetSize);
            
            %LocationShifter is to jitter the locations of adjacent samples
            %around the possible space (when set size is lower than max)
            LocationShifter = maxSetSize - SetSize;

            LocJitter = (0:LocationShifter);
            LocJitter = Shuffle(LocJitter);
            CurrentLocJitter = LocJitter(1);  

            startingLoc = 1 + CurrentLocJitter;
            endLoc = SetSize + CurrentLocJitter;
            Locs = (1:maxSetSize);
            TheseLocations = Locs(startingLoc:endLoc); %new range of locations, somewhere within the full range, randomly chosen for the current set size

            %change detection will always randomly select from the same seet of colors,
            %defined at the outset, whereas continuous report will first
            %randomly shift the colors around the color space, then
            %randomly select from that range for each trial            
            switch CurrentTask
                case 1

                    TheseColors = ChangeColors;

                case 2
                    
                    TheseColors = WheelColors;
                    
                    colorRotater = Shuffle(colorRotater);
                    ThisColorRotater = colorRotater(1);
                    startColor = 0 + ThisColorRotater;
                    
                    TheseColors = (TheseColors) + startColor;
                    
                case 3
                    
                    TheseColors = ChangeColors;

            end
     
            CurrentColors = Shuffle(TheseColors);

            R = zeros(SetSize, 1);
            G = zeros(SetSize, 1);
            B = zeros(SetSize, 1);                      
            
        %define colors and locations for this trial's samples, then draw
        %them
        for locations = 1:SetSize 
            
            R(locations) = rgb_values(CurrentColors(locations), 1);
            G(locations) = rgb_values(CurrentColors(locations), 2);
            B(locations) = rgb_values(CurrentColors(locations), 3);
            
            ThisColor = [R(locations) G(locations) B(locations)];
            
            if CurrentTask == 1 || CurrentTask == 2
                LocationIndex = TheseLocations(locations);
                CurrentLocation = CenterRectOnPointd(stimRect, circleX(LocationIndex), circleY(LocationIndex));
                Screen('FillRect', win, ThisColor, CurrentLocation);
                StimDuration = StimShow;
            
            elseif CurrentTask == 3
                CurrentLocation = CenterStim;
                Screen('FillRect', win, ThisColor, CurrentLocation);
                Screen('Flip', win);
                WaitSecs(CentralStimShow);
                %Screen('FillRect', win, fixColor, fixRect);
                Screen('Flip', win);
                WaitSecs(CentralDelay);
                StimDuration = 0;
            end
        end        
        
                Screen('FillRect', win, fixColor, fixRect);        
                Screen('Flip', win);
                WaitSecs(StimDuration);
                                            
                Screen('FillRect', win, fixColor, fixRect);       
                Screen('Flip', win);
                WaitSecs(WMdelay);
                
                
        ShownLocs = mat2str(TheseLocations);
        AllColors = mat2str(TheseColors);%the whole range for this trial
        ShownColors = mat2str(CurrentColors(1:SetSize));%the colors that ultimately got selected for this trial      
        
        
        %choose proper probe type for this block condition
        switch ProbeType
            
            case 1 %change detection
                
                %choose probe-matching condition
                ProbeMatch = ProbeConditions(trial);
                error = 'NA';
                
                switch ProbeMatch
                    
                    case 1 %match
                        
                        %randomly select one of the samples used on this trial
                        options = (1:SetSize);
                        options = Shuffle(options);
                        ChosenProbeLoc = options(1);
                        ProbeLoc = TheseLocations(ChosenProbeLoc); 
                        
                        ChosenProbeColor = options(1);
                                               
                        correctResp = matchResp;
                        
                    case 2 %novel non-match
                        
                        %choose the last color from the vector of randomly
                        %mixed colors from this trial--as long as the
                        %number of available colors is at least one more
                        %than the max set size, this color would not have
                        %appeared as a sample
                        options = (1:SetSize);
                        options = Shuffle(options);
                        ChosenProbeLoc = options(1);                        
                        ProbeLoc = TheseLocations(ChosenProbeLoc);
                                            
                        ChosenProbeColor = NumChangeColors;
                        
                        correctResp = nonmatchResp;                        
                
                    case 3 %lure                        
                        
                        if SetSize > 1
                            
                        %Randomly choose a lure color from what was shown
                        %at one of the other locations
                        options = (1:SetSize);
                        options = Shuffle(options);
                        ChosenProbeLoc = options(1);
                        ProbeLoc = TheseLocations(ChosenProbeLoc); 
                        
                        ChosenProbeColor = options(2);              
                        
                        correctResp = nonmatchResp;  
                        
                        elseif SetSize == 1
                        %if load = 1, then there are no lures, so just pick
                        %a non-match
                        options = (1:SetSize);
                        options = Shuffle(options);
                        ChosenProbeLoc = options(1);                        
                        ProbeLoc = TheseLocations(ChosenProbeLoc);
                                            
                        ChosenProbeColor = NumChangeColors;
                        
                        correctResp = nonmatchResp;
                        
                        end
                        
                            
                end
                
                CorrectProbeColor = CurrentColors(ChosenProbeColor);
                
                ProbeR = rgb_values(CurrentColors(ChosenProbeColor), 1);
                ProbeG = rgb_values(CurrentColors(ChosenProbeColor), 2);
                ProbeB = rgb_values(CurrentColors(ChosenProbeColor), 3); 

                ThisProbeColor = [ProbeR ProbeG ProbeB];
                
                        for locations = 1:SetSize 
                            
                            index = TheseLocations(locations);
                            CurrentLocation = CenterRectOnPointd(stimRect, circleX(index), circleY(index));
                            Screen('FrameRect', win, fixColor, CurrentLocation, ThinOutlineWidth);  

                        end

                CurrentProbeLocation = CenterRectOnPointd(stimRect, circleX(ProbeLoc), circleY(ProbeLoc));
                Screen('FillRect', win, ThisProbeColor, CurrentProbeLocation); 
                Screen('FrameRect', win, fixColorTwo, fixRect, ThinOutlineWidth); 
                DrawFormattedText(win, '?\n\n\n\n\n\n\n\n\n\n\n\n', 'center', 'center', black);
                Screen('Flip', win);
            
                tempTime = GetSecs;

                %collect memory probe keypresses and RTs    
                if IsOSX
                [probekeys, probeRT] = waitForKeys(GetSecs, ChangeProbe, KeyBoardNum, 1);
                else
                [probekeys, probeRT] = waitForKeys(GetSecs, ChangeProbe, 0, 1);
                end     

                while (GetSecs - tempTime) <= ChangeProbe        
                end
                     if probeRT == 0
                        probert = 999;
                        probeResp = 'NA';
                     else
                        probert = probeRT;
                        probeResp = num2str(probekeys(1));
                     end   

                msecProbeRT=round(1000*probert);
                msecProbeRT = num2str(msecProbeRT); % jms

                Accuracy = strcmp(probeResp,correctResp); 

                if Accuracy == 1 
                    probeACC = 1;
                else
                    probeACC = 0;
                end
                
                    response = probeResp;
                            
            case 2 %adjustment wheel
                
                ProbeMatch = 4; %just a notation in the data file that this was a precision probe

                    options = (1:SetSize);
                    options = Shuffle(options);
                    ChosenProbeLoc = options(1);
                    ProbeLoc = TheseLocations(ChosenProbeLoc); 
                    CurrentProbeLocation = CenterRectOnPointd(probeRect, circleX(ProbeLoc), circleY(ProbeLoc));

                    ChosenProbeColor = options(1);
                    CorrectProbeColor = CurrentColors(ChosenProbeColor);

                %make a wedge in the color wheel for every color in the space
                spacing = 360/NumColors;
                lastcolor = 360-spacing;
                wedgeRange = (0:spacing:lastcolor);

                %fill the wheel
                for j = 1:size(rgb_values, 1)
                    Screen('FillArc', win, rgb_values(j, :), colorWheel, wedgeRange(j), 2);
                end

                %show the rect for the probed color and the response box
                Screen('FillOval', win, gray, wheelCenter);
                Screen('FillRect', win, black, respBoxRect);
                DrawFormattedText(win, 'R', 'center', 'center', fixColor);
                
                        for locations = 1:SetSize                             
                            index = TheseLocations(locations);
                            CurrentLocation = CenterRectOnPointd(stimRect, circleX(index), circleY(index));
                            Screen('FrameRect', win, fixColor, CurrentLocation, ThinOutlineWidth); 
                        end
                
                Screen('FrameRect', win, black, CurrentProbeLocation, ThickOutlineWidth); 

                    ShowCursor('Arrow');

                    %puts mouse at center--but can be weird on multi-display
                    %setups
                    SetMouse(Xcenter, Ycenter);
                    [~, probeStart] = Screen('Flip', win);

                    respStart = probeStart;

                    enterResp=false;
                    clickCounter = 0;

                    colorClicked = 9999; %jms: reset this variable before each response phase to avoid wonky behavior if they don't respond at all

                    
                    while enterResp==false                        
                   
                        %[~, responseX, responseY, buttons] = GetClicks(win, 0);%gives coords of each click                         
                        [responseX, responseY, mouseClick] = GetMouse;
                        
                        %if any(buttons)                        
                        if mouseClick(1) == 1
                        
                            %if a click falls in the middle of the screen,
                            %off the wheel, do nothing
                            if responseX > fixRespX1 && responseX < fixRespX2 && responseY > fixRespY1 && responseY < fixRespY2
                                enterResp=false;

                            % if a click is closer to the wheel, update
                            %the color of the probe rect
                            else
                                [respRad, ~] = cart2pol(responseX - Xcenter, ...
                                (responseY - Ycenter) * 1); %this was -1 in this bit of code I borrowed from Dan/Kartik, but that makes wedge move in opposite direction from mouse, so idk
                            respAng = respRad / (2 * pi) * 360;
                            respAng = respAng+90; %let's check to be extra special double certain that i'm not effing up the error calculation in here somewhere    

                                if respAng < 0
                                    respAng = respAng + 360;
                                end

                                %colorClicked = find(wedgeRange == floor(respAng / 2) * 2);
                                colorClicked = find(wedgeRange == floor(respAng));
                                
                                for j = 1:size(rgb_values, 1)
                                    if j == colorClicked
                                        Screen('FillArc', win, black, colorWheel, wedgeRange(j), 2);
                                    else
                                        Screen('FillArc', win, rgb_values(j, :), colorWheel, wedgeRange(j), 2);
                                    end
                                end

                                Screen('FillOval', win, gray, wheelCenter);
                                Screen('FillRect', win, black, respBoxRect);
                                DrawFormattedText(win, 'R', 'center', 'center', fixColor);
                                
                                    for locations = 1:SetSize                             
                                        index = TheseLocations(locations);
                                        CurrentLocation = CenterRectOnPointd(stimRect, circleX(index), circleY(index));
                                        Screen('FrameRect', win, fixColor, CurrentLocation, ThinOutlineWidth); 
                                    end
                                    
                                Screen('FillRect', win, rgb_values(colorClicked, :),CurrentProbeLocation);
                                [~, respStart] = Screen('Flip', win, ...
                                    respStart + (waitFrames - 0.75) * ifi);
                                
                                clickCounter = clickCounter + 1;
                                
                            end  
                        end
                        
                        [~, ~, key_code] = KbCheck;
                        
                        if key_code(WheelRespKey)
                            enterResp = true;
                        end
                        
                        if GetSecs - probeStart > responseDeadline %responseDeadline defined above
                            enterResp = true; % this will break the response loop

                        end
                        
                    end 
                    
                                        
                    probert = GetSecs - probeStart;
                    msecProbeRT=round(1000*probert);
                    
                    if msecProbeRT > ((responseDeadline*1000)-1)
                        msecProbeRT = 'Time-out';
                        HideCursor; % To fix cursor bug, moved 'HideCursor' here instead of right before the 'Record trial data' section
                    else
                        HideCursor;
                        msecProbeRT = num2str(msecProbeRT);
                        %if a response is entered before the deadline, add
                        %in some extra fixation before the next trial
                        %starts, so all trials are equated in length
                        extraWait = responseDeadline - probert;
                        Screen('FillRect', win, fixColor, fixRect);       
                        Screen('Flip', win);
                        WaitSecs(extraWait);
                    end
                    
                    response = num2str(colorClicked);
                    
                    probeACC = abs(CorrectProbeColor-colorClicked); 
                    
                    if probeACC > 180
                        probeACC = (360 - probeACC);
                    end
                    
                    %some probably incredibly inefficient method of
                    %calculating errors (i.e., both clockwise and
                    %counterclockwise, whereas probeACC is just absolute value)
                    if (colorClicked > CorrectProbeColor && (colorClicked - CorrectProbeColor) > 180) || (colorClicked < CorrectProbeColor && (CorrectProbeColor - colorClicked) < 180)
                        error = -1*probeACC;
                    else
                        error = probeACC;
                    end
                    
                    if error > 180
                        error = 'NoResp';
                    else
                        error = num2str(error);
                    end

               
            case 3 %existence detection
                
                %choose probe-matching condition
                ProbeMatch = ProbeConditions(trial);
                error = 'NA';
                
                switch ProbeMatch
                    
                    case 1 %match
                        
                        %randomly select one of the samples used on this trial
                        options = (1:SetSize);
                        options = Shuffle(options);
                        
                        ChosenProbeColor = options(1);
                                               
                        correctResp = matchResp;
                        
                    case 2 %novel non-match
                        
                        %choose the last color from the vector of randomly
                        %mixed colors from this trial--as long as the
                        %number of available colors is at least one more
                        %than the max set size, this color would not have
                        %appeared as a sample
                                            
                        ChosenProbeColor = NumChangeColors;
                        
                        correctResp = nonmatchResp;                                               
                end
                
                CorrectProbeColor = CurrentColors(ChosenProbeColor);
                
                ProbeR = rgb_values(CurrentColors(ChosenProbeColor), 1);
                ProbeG = rgb_values(CurrentColors(ChosenProbeColor), 2);
                ProbeB = rgb_values(CurrentColors(ChosenProbeColor), 3); 

                ThisProbeColor = [ProbeR ProbeG ProbeB];

                ProbeLoc = 999; %to differentiate from spatial blocs in data file
                CurrentProbeLocation = CenterStim;
                Screen('FillRect', win, ThisProbeColor, CurrentProbeLocation); 
                %Screen('FillRect', win, fixColor, fixRect); 
                DrawFormattedText(win, '?\n\n\n\n\n\n\n', 'center', 'center', black);
                Screen('Flip', win);
                
                tempTime = GetSecs;

                %collect memory probe keypresses and RTs    
                if IsOSX
                [probekeys, probeRT] = waitForKeys(GetSecs, ChangeProbe, KeyBoardNum, 1);
                else
                [probekeys, probeRT] = waitForKeys(GetSecs, ChangeProbe, 0, 1);
                end     

                while (GetSecs - tempTime) <= ChangeProbe        
                end
                     if probeRT == 0
                        probert = 999;
                        probeResp = 'NA';
                     else
                        probert = probeRT;
                        probeResp = num2str(probekeys(1));
                     end   

                msecProbeRT=round(1000*probert);
                msecProbeRT = num2str(msecProbeRT); %jms

                Accuracy = strcmp(probeResp,correctResp); 

                if Accuracy == 1 
                    probeACC = 1;
                else
                    probeACC = 0;
                end  
                
                    response = probeResp;
                    
        end
        
 
      
    
    % record trial data

    %this is pretty sparse right now, but should include the essential
    %basics
     fprintf(fid,'%s, %s, %s, %s, %i, %s, %i, %i, %i, %i, %s, %s, %s, %i, %i, %i, %i, %d, %s, %d, %s, %s\n',...
        subject,...
        session,...
        target,...
        StimLat,...
        CurrentTask,...
        TaskCondition,...
        block,...
        trial,...
        CurrentSetSize,...
        SetSize,...
        ShownLocs,...
        AllColors,...
        ShownColors,...
        ProbeMatch,...
        ChosenProbeColor,...
        CorrectProbeColor,...
        ProbeLoc,...
        probert,...
        msecProbeRT,...
        probeACC,...
        response,...
        error);
    
    end
    
       %kindly give participants a helpful indicator of how much more
       %excrutiating misery they have left to endure
       if block == BlockNum
           message=sprintf('You are now done with the experiment \n \n \n Thanks for participating! \n \n');
       else
           thisblock = num2str(block);
           allblock = num2str(BlockNum);
           space = {' '};
           endmessage = strcat('You are done with run', space, thisblock, ' out of', space, allblock, '\n\n\n Press space to begin the next run');
           endmessage = char(endmessage);
           message=sprintf(endmessage);            
       end
    
    blockend = message;
    DrawFormattedText(win, blockend, 'center', 'center', 0);
    Screen('Flip', win);
    
        if IsOSX
        getKey('space', KeyBoardNum);
        else
            getKey('space');
        end
    
    end    

    %ListenChar(0);
    Screen('CloseAll');
    ShowCursor;
    FlushEvents;
    fclose('all');
    Priority(0);


end

% Some helper functions, don't worry about it
%------------------------------------------------------------------------
function [rgb_values] = RGBwheel_fromHSV(NumH, S, V)
%NumH is the total number of hues you want, i.e., 360 for a cicular space
%with 1 degree steps
%S and V will be constant 

ColorList = zeros(NumH, 3);

Saturation = S;
Value = V;%value (brightness)

Hrange = linspace(0, 1, NumH);
Srange = (Saturation * ones(1, length(Hrange)));
Vrange = (Value * ones(1, length(Hrange)));

ColorList(1:NumH, 1) = Hrange;
ColorList(1:NumH, 2) = Srange;
ColorList(1:NumH, 3) = Vrange;

RGBlist = hsv2rgb(ColorList);
rgb_values = 255*(RGBlist);

end
%-------------------------------------------------------------------------
function getKey(key,deviceNumber)

% Waits until user presses the specified key.
% Usage: getKey('a')
% JC 02/01/06 Wrote it.
% JC 03/31/07 Added platform check.

% Don't start until keys are released
if IsOSX
    if nargin<2
        fprintf('You are using OSX and you MUST provide a deviceNumber! getKey will fail.\n');
    end
    while KbCheck(deviceNumber) 
    end;
else
    if nargin>3
        fprintf('You are using Windows and you MUST NOT provide a deviceNumber! getKey will fail.\n');
    end
    while KbCheck end;  % no deviceNumber for Windows
end

while 1
    while 1
        if IsOSX
            [keyIsDown,secs,keyCode] = KbCheck(deviceNumber);
        else
            [keyIsDown,secs,keyCode] = KbCheck; % no deviceNumber for Windows
        end
        if keyIsDown
            break;
        end
    end
    theAnswer = KbName(keyCode);
    if ismember(key,theAnswer)  % this takes care of numbers too, where pressing 1 results in 1!
        break
    end
end
end

%----------------------------------------------------------------------------
function pix = angle2pix(viewDist, cmScreenWidth, width_pix, ang)
% pix = angle2pix(display,ang)
%
% converts visual angles in degrees to pixels.
%
% Inputs:
% viewDist (viewDistance from screen (cm))
% cmScreenWidth (width of screen (cm))
% width_pix (number of pixels of display in horizontal direction)
% ang (visual angle in degrees)
%
% Warning: assumes isotropic (square) pixels

rad = ang * 2 * pi / 360;
x = 2 * viewDist * tan(rad / 2);

% Calculate pixel size
pixSize = cmScreenWidth / width_pix;   % cm / pix

pix = round(x/pixSize);   % pix
end

%--------------------------------------------------------------------------

function [keys, RT] = waitForKeys(startTime,duration,deviceNumber,exitIfKey)

% Modified from collectKeys.
% NC (after JC) 11/27/07
% Collects keypresses for a given duration.
% Duration is in seconds.
% If using OSX, you MUST provide a deviceNumber.
% If using Windows, you do not need to provide a deviceNumber -- if you do,
% it will be ignored.
% Optional argument exitIfKey: if exitIfKey==1, function returns after
% first keypress. 
%
% Example usage: do this if duration = length of event
%   [keys RT] = recordKeys(GetSecs,0.5,deviceNumber)
%
% Example usage: do this if duration = endEvent-trialStart
%   goTime = 0;
%   startTime = GetSecs;  % This is the time the trial starts
%   goTime = goTime + pictureTime;  % This is the duration from startTime to the end of the next event
%   Screen(Window,'Flip');
%   [keys RT] = recordKeys(startTime,goTime,deviceNumber);
%   goTime = goTime + blankTime;    % This is the duration from startTime to the end of the next event
%   Screen(Window,'Flip');
%   [keys RT] = recordKeys(startTime,goTime,deviceNumber);
%
% A note about the above example: it's best to calculate the duration from
% the beginning of each trial, rather than from the beginning of each
% event. Some commands may cause delays (like Flip), and if you calculate
% duration by event, these delays will accumulate. If you calculate
% duration from the beginning of the trial, your presentations may be a
% tiny bit truncated, but you'll be on schedule. It's your call.
% Even better: calculate duration from the beginning of the experiment.
%
% Using deviceNumber:
% KbCheck only collects from the first key input device found. On a laptop,
% this is usually the laptop keyboard. However, often you'll want to collect
% from another device, like the buttonbox in the scanner! You MUST specify
% the device number, or none of the input from the buttonbox will be
% collected. Device numbers change according to what order the USB devices
% were plugged in, and you may find that you can only perform this check
% ONCE using the command d=PsychHID('Devices'); so DO NOT change the device
% arrangement (which port each is plugged into) after performing the check.
% Restarting Matlab will allow you to use d=PsychHID('Devices') again
% successfully.
% On Windows, KbCheck records simultaneously from all keyboards -- you
% cannot specify.
%
% collectKeys:
% JC 02/16/2006 Wrote it.
% JC 02/28/2006 Added deviceNumber.
% JC 08/14/2006 Added break if time is up, even if key is being held down.
% recordKeys:
% JC 03/31/2007 Changed from etime to GetSecs. Added platform check. Added cell check.
% JC 07/02/2007 Added exitIfKey.
% JC 08/02/2007 Fixed "Don't start until keys are released" to check for
% duration exceeded

keys = [];
RT = [];
myStart = GetSecs;    % Record the time the function is called (not same as startTime)

% Don't start until keys are released
if IsOSX
    if ~exist('deviceNumber','var')
        fprintf('You are using OSX and you MUST provide a deviceNumber! recordKeys will fail.\n');
    end
    while KbCheck(deviceNumber) 
        if (GetSecs-startTime)>duration, break, end
    end;
else
    while KbCheck % no deviceNumber for Windows
        if (GetSecs-startTime)>duration, break, end
    end;  
end

% Now check for keys
while 1
    if IsOSX
        [keyIsDown,secs,keyCode] = KbCheck(deviceNumber);
    else
        [keyIsDown,secs,keyCode] = KbCheck; % no deviceNumber for Windows
    end
    if keyIsDown
        keys = [keys KbName(keyCode)];
        RT = [RT GetSecs-myStart];
        break
        if IsOSX
            while KbCheck(deviceNumber)
                if (GetSecs-startTime)>duration, break, end
            end
        else
            while KbCheck
                if (GetSecs-startTime)>duration, break, end
            end
        end
        if exist('exitIfKey','var')
            if exitIfKey
                break
            end
        end
    end
    if (GetSecs-startTime)>duration, break, end
end

if isempty(keys)
    keys = 'noanswer';
    RT = 0;
elseif iscell(keys)  % Sometimes KbCheck returns a cell array (if multiple keys are mashed?).
    keys = '';
    RT = 0;
end
end

