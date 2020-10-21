/******************************* REXX *******************************/
/* Treasure is a game based on 'Treasure Hunt Program' taken        */
/* from the Usborne 1983 book 'Practise You Basic'.                 */
/*                                                                  */
/* This version by W Downie of 'Keep on Truckin' Productions' 2020  */
/*                                                                  */
/********************************************************************/
  Address ispexec
  "LIBDEF ISPPLIB DATASET ID('Z01408.ISPF.PANELS')"
  call init_variables
  call start_screen
  call room_screen

/*------------------------------------------------------------------*/
/* Main Loop                                                        */
/*------------------------------------------------------------------*/
  do forever
    roomnbr = player_room         /* set                */
    killnbr = killer_room         /*   variables        */
    liveleft = player_lives       /*           for      */
    movenbr = move_counter        /*             panel  */
    call build_screen
    "DISPLAY PANEL("panelid")"    /* clear out the screen_buffer */
    call parse_trace
    if player_lives = 0 then leave
    if verb \= 'Trace' then
      do
        if trace_on = 'y' then trace i
        call parse_input
        select
          when verb = 'Move' then call move_player
          when verb = 'Locate' then call display_contents
          when verb = 'Grab' then call get_treasure
          when verb = 'Put' then call put_treasure
          when verb = 'Swear' then call swear_box
          when verb = 'Help' then call display_help
          when verb = 'Error' then call display_error
          when verb = 'Exit' then leave
          otherwise nop
        end
      end
    if  player_room = 0 then           /* if player was killed      */
      do
        if player_lives = 0 then       /* if all lives gone, you've */
          call end_game_picture        /* had your chips.           */
        else
          do
            player_room = random(1,7)  /* else put in a new room.   */
            call room_screen           /* display the room          */
          end
      end
    input = ' '
    trace off
  end
  trace off
  exit 0

/*------------------------------------------------------------------*/
/* Build the opening screen graphic                                 */
/*------------------------------------------------------------------*/
  start_screen:
    do ix = 1 to intro_screen.0
      call append_screen_buffer intro_screen.ix
    end
  return

/*------------------------------------------------------------------*/
/* Build the end screen graphic                                     */
/*------------------------------------------------------------------*/
  end_game_picture:
    do ix = 1 to skull_graphic.0
      call append_screen_buffer skull_graphic.ix
    end
  return

/*------------------------------------------------------------------*/
/* Build the help screen                                            */
/*------------------------------------------------------------------*/
  display_help:
    do ix = 1 to help_screen.0
      call append_screen_buffer help_screen.ix
    end
  return

/*------------------------------------------------------------------*/
/* First check we make is whether we are turning trace on/off.      */
/* This is done prior to parsing the input properly. If we are      */
/* tracing all other processing is bypassed.                        */
/*------------------------------------------------------------------*/
  parse_trace:
    verb = ''
    if input = 'T' then
      do
        call append_screen_buffer blank_line
        call append_screen_buffer '> '||input  /* reflect input */
        verb = 'Trace'
        if trace_on = 'y' then
          do
            trace_on = ''
            call append_screen_buffer '*** Tracing disabled ***'
          end
        else
          do
            trace_on = 'y'
            call append_screen_buffer '*** Tracing enabled ***'
          end
      end
  return

/*------------------------------------------------------------------*/
/* Validate 'input' and set up 'verb'                               */
/* Ntry : input contains what the player has input                  */
/* Exit : verb contains value that main loop uses                   */
/*------------------------------------------------------------------*/
  parse_input:
    call append_screen_buffer blank_line
    call append_screen_buffer '> '||input  /* reflect input */
    do
      select
        when wordpos(input,parse_north) \= 0 then do
          direction = $north
          verb = 'Move'
        end
        when wordpos(input,parse_east) \= 0 then do
          direction = $east
          verb = 'Move'
        end
        when wordpos(input,parse_south) \= 0 then do
          direction = $south
          verb = 'Move'
        end
        when wordpos(input,parse_west) \= 0 then do
          direction = $west
          verb = 'Move'
        end
        when wordpos(input,parse_locate) \= 0 then verb = 'Locate'
        when wordpos(input,parse_grab) \= 0 then verb = 'Grab'
        when wordpos(input,parse_put) \= 0 then verb = 'Put'
        when wordpos(input,parse_help) \= 0 then verb = 'Help'
        when wordpos(input,parse_exit) \= 0 then verb = 'Exit'
        when wordpos(input,parse_swear) \= 0 then verb = 'Swear'

        otherwise verb = 'Error'
      end
      if player_lives = 0 then verb = 'Dead'
    end
  return

/*------------------------------------------------------------------*/
/* Ntry : player_room contains the room player is currently in      */
/*        'direction' contains $north, $south etc                   */
/*        These are used as tails in stem variable                  */
/*------------------------------------------------------------------*/
  move_player:
    if nextroom.player_room.direction = 0 then
      do
        call append_screen_buffer ,
                        'It is not possible to go in that direction'
      end
    else
      do
        move_counter = move_counter + 1
        player_room = nextroom.player_room.direction
        if players_dead(player_room, killer_room) \= 0 then
          do
            call killer_next_room
            call room_screen
          end
      end
  return

/*------------------------------------------------------------------*/
/* Take the treasure.                                               */
/* The treasure variable is set to the treasure and then room       */
/* number it was in is set to zero.                                 */
/*------------------------------------------------------------------*/
  get_treasure:
    if treasure \= ''  then
        call append_screen_buffer 'You are already carrying treasure'
    else
      do
        if players_dead(player_room, killer_room) \= 0 then
          do
            do ix = 1 to 7 until treasure_room.ix = 0
              if treasure_room.ix = player_room then
                do
                  treasure = ix
                  treasure_room.ix = 0
                  call append_screen_buffer ,
                           'You have picked up the '||treasure_name.ix
                  move_counter = move_counter + 1
                end
            end
            if ix = 8 then      /* no treasure in this room */
              call append_screen_buffer ,
                'There is no treasure in this room'
            else
              do
                call killer_next_room
                call check_for_killer
              end
          end
      end
  return

/*------------------------------------------------------------------*/
/* Put the treasure                                                 */
/*------------------------------------------------------------------*/
  put_treasure:
    if treasure = '' then
        call append_screen_buffer 'You are not carrying any treasure'
    else
      do
        if players_dead(player_room, killer_room) \= 0 then
          do
            treasure_room.treasure = player_room
            call append_screen_buffer ,
                       'You have dropped the '||treasure_name.treasure

            treasure = ''
            move_counter = move_counter + 1
            call killer_next_room
            call check_for_killer
          end
      end
    call check_completed
  return

/*------------------------------------------------------------------*/
/* Display what player is carrying and the contents of each room    */
/*------------------------------------------------------------------*/
  display_contents:
    call append_screen_buffer 'You are in room '||player_room
    call append_screen_buffer 'You must get all treasure into room '||,
                                                  room_to_put_treasure
    if treasure = '' then
      call append_screen_buffer 'You are carrying : '||'nothing'
    else call append_screen_buffer 'You are carrying : ',
                                              treasure_name.treasure
    call append_screen_buffer blank_line
    call append_screen_buffer 'Contents of the rooms:'
    do ix=1 to 7  /* rooms 1 to 7  */
      if treasure_room.ix \= 0 then
        call append_screen_buffer ,
                        '  '||treasure_room.ix||' : '||treasure_name.ix
    end
    call check_completed
  return

/*------------------------------------------------------------------*/
/* The player swore  !                                              */
/*------------------------------------------------------------------*/
  swear_box:
    call append_screen_buffer ,
      input||' is a terrible word. I expected better from you !!!'
  return

/*------------------------------------------------------------------*/
/* Redisplay the error                                              */
/*------------------------------------------------------------------*/
  display_error:
    call append_screen_buffer 'I dont know the word "'||input||'"'
  return

/*------------------------------------------------------------------*/
/* Check if killer is in the vacinity and put relevant msg to buffer*/
/*------------------------------------------------------------------*/
  check_for_killer:
    do ix = 1 to 4
      dir = word(directions,ix)
      if nextroom.killer_room.dir = player_room then
        call append_screen_buffer ,
          'You feel a presence in a nearby room'
    end
    if killer_room = player_room then
      call append_screen_buffer ,
        'There is a deathly presense in the room'
  return

/*------------------------------------------------------------------*/
/* Choose next room for killter to move to.                         */
/*------------------------------------------------------------------*/
  killer_next_room:
    room_list = ''
    do ix = 1 to 4
      dir = word(directions,ix)
      room_list = strip(room_list||nextroom.killer_room.dir,T,'0')
    end
    killer_room = substr(room_list,random(1,length(room_list)),1)
  return

/*------------------------------------------------------------------*/
/* Decide if player has been killed.                                */
/* Ntry: Room # that player and killer are in                       */
/* Exit: Returns 0 if player is dead                                */
/*------------------------------------------------------------------*/
  players_dead:
    parse arg room1, room2
    if room1 - room2 = 0 then
      do
        player_lives = player_lives - 1
        if player_lives \= 0 then do
          call append_screen_buffer ,
            'You have been killed, you were not careful....'
          call append_screen_buffer blank_line
          if treasure \= '' then     /* was player carrying treasure*/
            do
              treasure_room.treasure = player_room /* drop treasure */
              treasure = ''
            end
        end
        player_room = 0              /* flag player was killed      */
      end
    return room1 - room2

/*------------------------------------------------------------------*/
/* Display information about current room.                          */
/* Ntry : player_room contains room number                          */
/*------------------------------------------------------------------*/
  room_screen:
  /* Display room number */
    call append_screen_buffer 'You are in room '||player_room

  /* Display room description */
    call append_screen_buffer 'It is '||roomdesc.player_room

  /* Display treasure in room, if there are any */
  /* Firstly move the treasures into a stem     */
    treasure_list.0 = 0
    iy = 1
    do ix = 1 to 7
      if treasure_room.ix = player_room then
        do
          treasure_list.iy = treasure_name.ix
          treasure_list.0 = treasure_list.0 + 1
          iy = iy + 1
        end
    end

  /* Move from treasure_list stem to screen buffer     */
    if treasure_list.0 \= 0 then
      do
        tstring = 'It contains '
          do iy = 1 to treasure_list.0
            tstring = tstring||treasure_list.iy
            if (treasure_list.0 - iy) > 1 then
              tstring = tstring||', '
            else
              if (treasure_list.0 - iy) = 1 then
                tstring = tstring||' and '
          end

          call append_screen_buffer tstring
      end

    /* check for killer and display details */
    call check_for_killer
    /* blank line */
    call append_screen_buffer blank_line

    /* Ask what player wants to do */
    call append_screen_buffer 'What do you want to do ?'

  return

/*------------------------------------------------------------------*/
/* Append to screen buffer                                          */
/* This splits up string if it is longer than max_col. It does the  */
/* split at the first space from the end of the largest string      */
/* that will fit on a line.                                         */
/*------------------------------------------------------------------*/
  append_screen_buffer:
    string = arg(1)
    do while length(string) >= max_col
      work = left(string,max_col)
      do ix = 1 to 999
         if substr(reverse(work),ix,1) = ' ' then leave
      end
      ix = length(work) - (ix - 1)
      work = left(string,ix)
      screen_buff.0 = screen_buff.0 + 1 ; iy = screen_buff.0
      screen_buff.iy = work
      string = right(string,length(string)-ix)
    end
    screen_buff.0 = screen_buff.0 + 1 ; iy = screen_buff.0
    screen_buff.iy = string

  return

/*------------------------------------------------------------------*/
/* Build the screen                                                 */
/* screen_buff contains a string of screen lines. Each line is      */
/* seperated with a <>.  Move each line into a stem leaf (split.)   */
/* From stem, populate line1 thru line37, the order si reversed,    */
/* e.g. the highest stem leaf is moved to lowest line (line 1).     */
/* the screen.                                                      */
/* Ntry : screen_buff contains data to move to screen               */
/* Exit : ISPF variables line1 thru line37  will be populated.      */
/*------------------------------------------------------------------*/
  build_screen:
    trace off      /* don't bother to trace this */
    do ix = max_row to 1 by -1          /* this moves lines up the */
      new_line_nbr = ix + screen_buff.0 /* 'console' to allow room */
      if new_line_nbr <= max_row then   /* for new lines in split. */
        do
          xxx = "line" || new_line_nbr
          yyy = "line" || ix
          interpret xxx " = " yyy
       end
    end
    iy = screen_buff.0                  /* move lines from split.  */
    do ix = 1 to screen_buff.0          /* to bottom of 'console'. */
      xxx = "line" || iy
      interpret xxx " = screen_buff.ix"
      iy = iy - 1
    end
    screen_buff. = ' '                  /* clear out the screen     */
    screen_buff.0 = 0                   /*                  buffer  */
  return

/*------------------------------------------------------------------*/
/* Check if all treasure in one room and set msg if it is           */
/*------------------------------------------------------------------*/
  check_completed:
    do ix = 1 to 7 while treasure_room.ix = room_to_put_treasure
      nop
    end

    if ix = 8 then
      do
        call append_screen_buffer blank_line
        call append_screen_buffer ,
                      'Well done ! All treasure is in room '|| ,
                                                  room_to_put_treasure
      end

  return

/*------------------------------------------------------------------*/
/* One time call to set up stems  and init variables                */
/*------------------------------------------------------------------*/
  init_variables:
    treasure = ''
    trace_on = ''
    move_counter = 0
    player_lives = 3
    player_room = random(1,7)
    killer_room = random(1,7)
    room_to_put_treasure = random(1,7)
  /*player_room = 2
    killer_room = 3
    room_to_put_treasure = 2*/
    max_col = 76

    "VGET (ZSCRMAXD)"
     panelid = 'GAME2'           /* default to model 2 */
     max_row = 20
    select                       /* set max number of rows */
      when ZSCRMAXD = 24 then    /* Model 2 */
        do
          panelid = 'GAME2'
          max_row = 20
        end
      when ZSCRMAXD = 43 then    /* Model 4 */
        do
           panelid = 'GAME4'
           max_row = 39
        end
      when ZSCRMAXD = 27 then    /* Model 5 */
        do
          panelid = 'GAME5'
          max_row = 23
        end
      otherwise exit 12
    end

    do ix = 1 to max_row     /* line variables are lines on panel */
      xxx = "line" || ix
      interpret xxx "= ' '"
    end
    blank_line = ' '

    screen_buff. = ' '
    screen_buff.0 = 0

    intro_screen.0 = 13
    intro_screen.1 = "._______                                "
    intro_screen.2 = "|__   __|                               "
    intro_screen.3 = "...| |_ __ ___  __ _ ___ _   _ _ __ ___ "
    intro_screen.4 = "...| | '__/ _ \/ _` / __| | | | '__/ _ \"
    intro_screen.5 = "...| | | |  __/ (_| \__ \ |_| | | |  __/"
    intro_screen.6 = "...|_|_|  \___|\__,_|___/\__,_|_|  \___|"
    intro_screen.7 = "                                        "
    intro_screen.8 = "2020 Copyright (c) Keep on Truckin' Productions"
    intro_screen.9 = " "
    intro_screen.10 = ,
            "There are seven rooms in the house and there treasure in"
    intro_screen.11 = ,
           "each room. You must get all the treasure into room "
    intro_screen.11 = intro_screen.11||room_to_put_treasure||"."
    intro_screen.12 = "Be careful, something else is out there."

    intro_screen.13 = " "

    skull_graphic.0  = 14
    skull_graphic.1  = "               _( )                 ( )_  "
    skull_graphic.2  = "               (_, |      __ __      | ,_)"
    skull_graphic.3  = "                  \'\    /  ^  \    /'/   "
    skull_graphic.4  = "                   '\'\,/\      \,/'/'    "
    skull_graphic.5  = "                     '\| []   [] |/'      "
    skull_graphic.6  = "                       (_  /^\  _)        "
    skull_graphic.7  = "                         \  ~  /          "
    skull_graphic.8  = "                         /HHHHH\          "
    skull_graphic.9  = "                       /'/{^^^}\'\        "
    skull_graphic.10 = "                   _,/'/'  ^^^  '\'\,_    "
    skull_graphic.11 = "                  (_, |           | ,_)   "
    skull_graphic.12 = "                    (_)           (_)     "
    skull_graphic.13 = "                                          "
    skull_graphic.14 = ,
         "Sorry you have no lives left :(  hit any key to leave."

    help_screen.0 = 8
    help_screen.1 = "These are the words the computer understands "
    help_screen.2 = "                                             "
    help_screen.3 = "N,E,S,W : Move North, East, South or West    "
    help_screen.4 = "Grab    : Pick up treasure                   "
    help_screen.5 = "Put     : Put down treasure                  "
    help_screen.6 = "Locate  : Prints current location of treasure"
    help_screen.7 = "Help    : Tells you how to play the game     "
    help_screen.8 = "                                             "

    parse_north = 'N NORTH UP'     ; parse_south = 'S SOUTH DOWN'
    parse_east  = 'E EAST RIGHT'   ; parse_west = 'W WEST LEFT'
    parse_locate = 'L LOOK LOCATE' ; parse_grab = 'G GRAB GET TAKE'
    parse_put = 'P PUT DROP'       ; parse_exit = 'Q X QUIT EXIT'
    parse_trace = 'T TRACE'        ; parse_help = '?'
    parse_swear = 'POO SHIT BUM FUCK HELL'

  /* next room number. e.g. if in room 1 and going north the next   */
  /* room will be 2.                                                */
    nextroom.1.$north = 2 ; nextroom.1.$east = 7
    nextroom.1.$south = 6 ; nextroom.1.$west = 0
    nextroom.2.$north = 0 ; nextroom.2.$east = 3
    nextroom.2.$south = 7 ; nextroom.2.$west = 1
    nextroom.3.$north = 0 ; nextroom.3.$east = 0
    nextroom.3.$south = 4 ; nextroom.3.$west = 2
    nextroom.4.$north = 3 ; nextroom.4.$east = 0
    nextroom.4.$south = 5 ; nextroom.4.$west = 7
    nextroom.5.$north = 7 ; nextroom.5.$east = 4
    nextroom.5.$south = 0 ; nextroom.5.$west = 6
    nextroom.6.$north = 1 ; nextroom.6.$east = 5
    nextroom.6.$south = 0 ; nextroom.6.$west = 0
    nextroom.7.$north = 2 ; nextroom.7.$east = 4
    nextroom.7.$south = 5 ; nextroom.7.$west = 1

    directions = '$NORTH $EAST $SOUTH $WEST'

    roomdesc.1 = 'Cold and creepy'
    roomdesc.2 = 'Dark and dingy'
    roomdesc.3 = 'Grey and ghostly'
    roomdesc.4 = 'Foul and foggy'
    roomdesc.5 = 'Empty and eerie'
    roomdesc.6 = 'Haunted and horrible'
    roomdesc.7 = 'Spooky and scary'

    treasure_name.1 = 'Murder She Wrote box set'
    treasure_name.2 = 'Cheese sandwiches'
    treasure_name.3 = 'Rod Stewart LPs'
    treasure_name.4 = 'Plate of fish and chips'
    treasure_name.5 = 'Scraps of fish a cat would enjoy'
    treasure_name.6 = 'Joan Collins biography'
    treasure_name.7 = 'Signed picture of Bette Davis'

  /*treasure          room # */
    treasure_room.1 = 1    /* e.g. Gold is in room 1 */
    treasure_room.2 = 2
    treasure_room.3 = 3
    treasure_room.4 = 4
    treasure_room.5 = 5
    treasure_room.6 = 6
    treasure_room.7 = 7

  return

