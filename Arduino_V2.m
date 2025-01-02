clear; %Stops the error; 'MATLAB connection to Uno at COM5 exists in your workspace. To create a new connection, clear the existing object.'
close all; %Closes windows and figures
clc; %Clears the Command Window

function [] = main()
    disp("Booting...")

    AngleData = readtable("AngleData.csv"); %Gets the angle experiment data
    arduinoObj = arduino("COM5", "Uno", "Libraries", "Ultrasonic"); %Creates connection to board
    ultrasonicObj = arduinoio.Ultrasonic(arduinoObj, 'D11', 'D12'); %Sets up ultrasonic sensor with arduino. NOTE: 'arduinoio.Ultrasonic()' = 'ultrasonic()'

    fileName = 'ResultsFile.mat'; %File name for saving results to

    distNum = 6; %Defult 6
    numFreq = 50; %Defult 100

    coefs = calibrate(distNum, fileName);
    activeMenu = true;

    %Lets the user choose a function 
    while (activeMenu)
        choice = menu("Select Function: ", "Re calibrate", "Ruler", "RulerCon", "Instrument", "Pong", "Analyse AngleData", "Quit");
        switch choice
            case 1 
                init_setup(distNum, numFreq, fileName, ultrasonicObj);
                disp("Calibration Successful")
            case 2
                ruler(coefs, 0, numFreq, ultrasonicObj);
            case 3
                ruler(coefs, 1, numFreq, ultrasonicObj);
            case 4
                instrument(coefs, ultrasonicObj);
            case 5
                pong(coefs, ultrasonicObj);
            case 6
                Analyse_AngleData(AngleData);
            case 7
                disp("Goodbye!")
                activeMenu = false;
        end
    end
end

%This collects the data necessary to correct the USS measurements
function [] = init_setup(distNum, numFreq, fileName, ultrasonicObj)
    disp("Loading data collection...")

    resultsTable = zeros(numFreq + 1, distNum); %rows x columns, first column for true values

    for i = 1:distNum
        disp("Measurement number " + i + "/" + distNum);
        trueDist = input("Enter manually measured distnace in metres: ");
        resultsTable(1, i) = trueDist;
        for j = 1:numFreq
            distance = readDistance(ultrasonicObj); %Takes distance measurement
            resultsTable(j + 1, i) = distance;
        end
        disp(" ")
    end
    save(fileName, "resultsTable") %Saves to a file
end

%Uses measurements collected to find line of best fit
function coefs = calibrate(distNum, fileName)
    %Loaded data bellow is a struct, needs to be extracted
    loadedData = load(fileName);

    %Extracts data
    resultsTable = loadedData.resultsTable;

    x = zeros(1, distNum);
    y = zeros(1, distNum);
    
    %Puts all the real values and all the averaged values into a list
    for i = 1:distNum
        y(i) = resultsTable(1, i);
        x(i) = mean(resultsTable(2:end, i));
    end

    coefs = polyfit(x, y, 1);
end

%Takes measurements and applies the correction
function [] = ruler(coefs, con, numFreq, ultrasonicObj)
    %If con is true, the function will take non-stop measurements
    running = true;
    while (running)
        %takeReading = questdlg(prompt text, title, option 1, option 2, defult option)
        takeReading = questdlg("Please select: ", "Take Reading", 'Take Reading', 'Quit', 'Take Reading');

        %Worth noting that questdlg() returns the string chosen, while
        %menu() returns the index of option chosen
        switch takeReading
            case "Take Reading"
                %The continuous measurements section
                if (con)
                    while con
                        disp("Please wait...")
                        distList = zeros(1, numFreq);
                        %dist1 is measured, dist2 is the 'corrected'
                        for i = 1:numFreq
                            distList(i) = readDistance(ultrasonicObj);
                        end
                        dist1 = mean(distList);
                        dist2 = coefs(1) * dist1 + coefs(2);
                        disp("Distance: " + dist2)
                        disp(" ")
                    end
                else
                    disp("Please wait...")
                    distList = zeros(1, numFreq);
                    %dist1 is measured, dist2 is the 'corrected'
                    for i = 1:numFreq
                        distList(i) = readDistance(ultrasonicObj);
                    end
                    dist1 = mean(distList);
                    dist2 = coefs(1) * dist1 + coefs(2);
                    disp("Distance: " + dist2)
                    disp(" ")
                end
            case "Quit"
                running = false;
        end
    end
end

%This was a function to attempt to turn the distances into a musical
%instrument, however failed due to its lower accuracy and slow speed
function [] = instrument(coefs, ultrasonicObj)
    %These are the notes to be played (C major scale, aka all the white
    %keys on the piano)
    C3 = 130.8;
    D3 = 146.8;
    E3 = 164.8;
    F3 = 174.6;
    G3 = 196;
    A3 = 220;
    B3 = 246.9;

    %Including higher octives, where each pitch is twice of that before
    frequencies = [C3, D3, E3, F3, G3, A3, B3... 
                   2*C3, 2*D3, 2*E3, 2*F3, 2*G3, 2*A3, 2*B3...
                   4*C3, 4*D3, 4*E3, 4*F3, 4*G3, 4*A3, 4*B3...
                   8*C3, 8*D3, 8*E3, 8*F3, 8*G3, 8*A3, 8*B3];

    %Max and min distance to be used, essentially the 'playable' area
    maxDist = 1.5;
    minDist = 0.3;

    %The active range of freqencies used 
    maxFreq = 2000;
    minFreq = 120;

    numFreq = 50; %How many distance samples will be taken (more = slower)

    Fs = 44100; % Sampling frequency (Hz)
    duration = 1; % Duration of the sound (seconds)
    
    % Generate the sine wave
    t = 0:1/Fs:duration; % Time vector (idk)
    signal = 0; %The initial pitch of sound
    
    running = true;
    while (running)
        tic;
        sound(signal, Fs); %Plays the sound at signal frequency

        %Finds the distance of object
        distList = zeros(1, numFreq);
        for i = 1:numFreq
            distList(i) = readDistance(ultrasonicObj);
        end
        dist1 = mean(distList);
        dist2 = coefs(1) * dist1 + coefs(2);
        
        %If distance is within range, convert to frequency
        if (dist2 <= maxDist && dist2 >= minDist)
            multiplier = (maxDist - dist2)/(maxDist - minDist);
            newFreq = multiplier * (maxFreq - minFreq) + minFreq;
            [~, index] = min(abs(frequencies - newFreq));
            note = frequencies(index);

            %Worth noting that this method of convertion is bad, since the
            %frequencies follow an exponential realtion, whereas the
            %convertion uses a linear relation
        else
            note = 0;
        end
        signal = sin(2 * pi * note * t); % Sine wave
        elapsedTime = toc;
        
        %The process was to slow for true continuous sound, so this was an
        %attempt to make it sound better by having each note play for the
        %same amount of time (since time taken for USS measurements varies)
        if (elapsedTime < duration)
            pause(duration - elapsedTime);
        end
    end
end

function [player, AI, ballPos] = init(padelSize, boardLen) %Initializes stuff
    %Remeber rows x collumns and 0,0 is top left
    %Keep everything odd for nice centres
    centre = floor(boardLen/2) + 1;
    ballPos = [centre, centre];

    player = [boardLen - 2, centre - floor(padelSize/2)]; %Initial player coords (far left point)
    AI = [3, centre - floor(padelSize/2)]; %Initial AI coords
end

function [] = update_screen(player, AI, ballPos, padelSize, boardLen) %Updates screen with current positions
    %Creates a black board
    board = zeros(boardLen, boardLen);

    %Puts a white pixel for the ball
    board(ballPos(1), ballPos(2)) = 1;

    %Draws the padels in white
    for i = 1:padelSize
        board(player(1), player(2) + i-1) = 1;
        board(AI(1), AI(2) + i-1) = 1;
    end

    imshow(board, 'InitialMagnification', 'fit', 'Border','tight'); %Displays board

    %This was to try and fix the window being un focused when first started
    %but I dont think it worked
    figHandle = gcf; 
    figHandle.WindowState = 'normal';
end

%Calculates where the players padel should be rendered given the USS distance
function player_x = calc_player(padelSize, boardLen, minDist, maxDist, numFreq, coefs, ultrasonicObj)
    %Finds USS distance
    distList = zeros(1, numFreq);
    for i = 1:numFreq
        distList(i) = readDistance(ultrasonicObj);
    end
    dist1 = mean(distList);
    dist2 = coefs(1) * dist1 + coefs(2);
    
    %If distance is within playable range
    if (dist2 <= maxDist && dist2 >= minDist)
        mappedValue = (boardLen - padelSize) - ((dist2 - minDist) / (maxDist - minDist)) * (boardLen - padelSize - 1);
        %Rounds to one pixel
        player_x = round(mappedValue);
    %Sets the padel far left or far right depending if measured distance is
    %too small or too large
    elseif dist2 > maxDist
        player_x = 1;
    else
        player_x = boardLen - padelSize + 1; %Sets player to the far right
    end
end

%Handles ball collision
function ballVel = ball_collision(padelSize, boardLen, player, AI, ballPos, ballVel)

    middle = floor(padelSize/2) + 1; %Finds padel centre

    %If ball is travelling towards player, and is in line with player
    if ballVel(1) > 0 && ballPos(1) == boardLen - 2 %Check player collision
        for i = 1:padelSize
            if ballPos(2) == player(2) + i - 1
                if i == middle
                    ballVel(1) = -ballVel(1);
                else
                    if i == padelSize
                        %The use of j was a crappy fix. When i ==
                        %padelSize, the dec returned was 1, angle was pi,
                        %therefore sin is 0 and cos is 1. This means the
                        %ball travelled perfectly horizontal and got stuck
                        %forever
                        j = padelSize - 1;
                    else
                        j = i;
                    end
                    %Finds an angle between 0 and pi based on input decimal
                    dec = j/padelSize;
                    theta = dec * pi;
                    ballVel = [-sin(theta), -cos(theta)];
                end
            end
        end
    %If ball is travelling towards AI and in line with AI
    elseif ballVel(1) < 0 && ballPos(1) == 3 %Check AI collision
        for i = 1:padelSize
            if ballPos(2) == AI(2) + i - 1
                if i == middle
                    ballVel(1) = -ballVel(1);
                else
                    %Same crappy 'j' fix
                    if i == padelSize
                        j = padelSize - 1;
                    else
                        j = i;
                    end
                    %Finds an angle between 0 and pi based on input decimal
                    dec = j/padelSize;
                    theta = dec * pi;
                    ballVel = [sin(theta), -cos(theta)];
                end
            end
        end
    end

    if ballVel(2) > 0 %Check right wall
        if ballPos(2) == boardLen
            ballVel(2) = -ballVel(2);
        end
    elseif ballVel(2) < 0 %Check left wall, if = 0 do nothing
        if ballPos(2) == 1
            ballVel(2) = -ballVel(2);
        end
    end
    %Worth noting that if the ball colides with a wall and the player/AI
    %simultaneously, pretty sure it spits out an error
end

%Put in seperate function for clarity
function ballPos = calc_ballPos(ballPos, ballVelocity)
    ballPos = ballPos + ballVelocity;
    ballPos = round(ballPos);
end

%Calculates the AI's movement
function AI_x = calc_AI(padelSize, boardLen, ballPos, perfect)
    if perfect == false
        %The AI will match the ball's x to any one if its sqaures,
        %technically should still be perfect, however because the game is
        %so janky, it sometimes misses
        randNum = randi([1, padelSize]);
        AI_x = ballPos(2) - randNum;

        %These catch the cases where the AI tries to put itself out of
        %bounds
        if AI_x < 1
            AI_x = 1;
        elseif AI_x > boardLen - padelSize + 1
            AI_x = boardLen - padelSize + 1;
        end
    else
        adjustment = floor(padelSize/2); %Offset amount to be at centre
        %Basically, if ball is in the middle area of the screen, with 
        %centre of padel, if ball is at the edge, go to the edge
        if ballPos(2) > 2
            if ballPos(2) < boardLen - adjustment + 1
                AI_x = ballPos(2) - adjustment;
            else
                AI_x = boardLen - padelSize + 1;
            end
        else
            AI_x = 1;
        end
    end

end

%Checks if the ball is behind either padel
function win = check_win(ballPos, boardLen)
    if ballPos(1) == 1
        win = 1; %Player wins
    elseif ballPos(1) == boardLen
        win = -1; %AI wins
    else
        win = 0; %No one has won
    end
end

function [] = pong(coefs, ultrasonicObj)
    %The ball speed is capped at FPS and FPS is capped by the Ultrasonic
    ballSpeed = 10000; %Measured in pixels per second
    ballVel = [-1, 0]; %An initial velocity directed at the AI head on (normalized)
    FPS = 10;

    perfect = true; %whether or not the AI plays perfect or not

    padelSize = 5;
    boardLen = 25;

    minDist = 0.3;
    maxDist = 1;

    %How many readings the USS averages over, higher number = runs slower
    numFreq = 5;

    %Initializes
    [player, AI, ballPos] = init(padelSize, boardLen);

    running = true;
    ballStart = tic;
    while (running)
        frameStart = tic; %Keeps FPS
        ballElapsed = toc(ballStart);%Keeps ball speed
        if (ballElapsed >= 1/ballSpeed)
            ballPos = calc_ballPos(ballPos, ballVel);
            ballStart = tic;
        end

        %Updates padels and ball
        AI(2) = calc_AI(padelSize, boardLen, ballPos, perfect);
        player(2) = calc_player(padelSize, boardLen, minDist, maxDist, numFreq, coefs, ultrasonicObj);
        ballVel = ball_collision(padelSize, boardLen, player, AI, ballPos, ballVel);

        %Checks for win
        win = check_win(ballPos, boardLen);
        if win ~= 0
            running = false;
        end
        %Draws everything to screen
        update_screen(player, AI, ballPos, padelSize, boardLen)
        frameElapsed = toc(frameStart);
        if frameElapsed < 1/FPS
            pause(1/FPS - frameElapsed)
        end

        %Negative value means the screen cant keep up with FPS
        disp(1/FPS - frameElapsed);
    end

end

function [] = Analyse_AngleData(AngleData)
    angle = menu("Select Angle (degrees): ", "0", "15", "30", "45", "60", "75", "Quit");

    %The quit option
    if angle == 7
        return
    end
    
    %Defining size of arrays before using them
    avgValues = zeros(1, 6);
    realValues = zeros(1, 6);
    

    for i = 1:6
        %Adds all the real distances to an array (ie. 0.25, 0.4, etc)
        realValues(i) = AngleData.Distance(1 + 6 * (i-1));

        %Adds all the measured distances for a specific angle to the array
        %Note that angle is a number between 1 and 6 inclusive
        avgValues(i) = AngleData.AvgMeasure(angle + 6 * (i-1));
    end

    %Plots the graph
    fig = figure;
    hold on
    plot(realValues, avgValues, '-o');
    plot(realValues, realValues);
    hold off

    %Properties of graph
    title = 15 * (angle - 1);
    title = "Angle of " + num2str(title) + " degrees";
    set(fig, 'Name', title)
    xlabel("Real Distances / m")
    ylabel("Measured Distances / m")
end

main();

close all;
