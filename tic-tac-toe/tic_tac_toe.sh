#!/bin/bash

BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[33m'
NO_COLOR='\033[0m'
RED_X="${RED}X${NO_COLOR}"
BLUE_O="${BLUE}O${NO_COLOR}"

board=($BLUE_O $RED_X $RED_X $RED_X $BLUE_O $BLUE_O $RED_X $BLUE_O $BLUE_O)
player1_name="Player 1"
player2_name="Player 2"
current_player=1
game_over=false
moves=0
save_file="tic_tac_toe_save.txt"
opponent_choice=0

winning_combinations=(
	0 1 2
	3 4 5
	6 7 8
	0 3 6
	1 4 7
	2 5 8
	0 4 8
	2 4 6
)

function print_board {
	clear
	echo -e "${YELLOW}Tic-tac-toe: the bash edition${NO_COLOR}\n"
	echo -e " ${board[0]} | ${board[1]} | ${board[2]}"
	echo "---|---|---"
	echo -e " ${board[3]} | ${board[4]} | ${board[5]}"
	echo "---|---|---"
	echo -e " ${board[6]} | ${board[7]} | ${board[8]}"
	echo
	printf "${YELLOW}${player1_name} (${RED}X${YELLOW}) vs ${player2_name} (${BLUE}O${NO_COLOR})\n"
	echo
}

function get_player_names {
	while true; do
		read -p "Enter Player 1's name: " player1_name
		if [[ ! $player1_name =~ ^[a-zA-Z]+$ ]]; then
			echo "Player 1's name can only contain letters (a-z, A-Z). Try again."
		else
			break
		fi
	done

	while true; do
		read -p "Enter Player 2's name: " player2_name
		if [[ ! $player2_name =~ ^[a-zA-Z]+$ ]]; then
			echo "Player 2's name can only contain letters (a-z, A-Z). Try again."
		elif [ "$player2_name" = "$player1_name" ]; then
			echo "Player 2's name cannot be the same as Player's 1. Try again."
		else
			break
		fi
	done
}

function move_ai {
	echo "AI is thinking."
	sleep 1

	free_cells=()
	for i in "${!board[@]}"; do
		if [[ ${board[$i]} =~ [1-9] ]] && [[ ${board[$i]} != "${RED_X}" ]] && [[ ${board[$i]} != "${BLUE_O}" ]]; then
			free_cells+=($i)
		fi
	done

	random_move=$((RANDOM % ${#free_cells[@]}))
	move=${free_cells[$random_move]}
	board[$move]="${BLUE_O}"

	print_board
}

function play {
	while ! $game_over; do
		if [ $opponent_choice -eq 2 ] && [ $current_player -eq 2 ]; then
			move_ai
		else
			read -p "$([ $current_player == 1 ] && echo "$player1_name" || echo "$player2_name"), enter your move (1-9): " move

			if ! [[ "$move" =~ ^[1-9]$ ]]; then
				echo "Invalid input. Please enter a number between 1 and 9."
				continue
			fi

			move=$((move - 1))

			if [[ ${board[$move]} == "${RED_X}" || ${board[$move]} == "${BLUE_O}" ]]; then
				echo "Invalid move. Try again."
				continue
			fi

			board[$move]=$([ $current_player == 1 ] && echo "${RED_X}" || echo "${BLUE_O}")
		fi

		print_board

		for ((i = 0; i < ${#winning_combinations[@]}; i += 3)); do
			combo=(${winning_combinations[i]} ${winning_combinations[i + 1]} ${winning_combinations[i + 2]})
			if [[ ${board[combo[0]]} == "$RED_X" && ${board[combo[1]]} == "$RED_X" && ${board[combo[2]]} == "$RED_X" ]] || [[ ${board[combo[0]]} == "$BLUE_O" && ${board[combo[1]]} == "$BLUE_O" && ${board[combo[2]]} == "$BLUE_O" ]] ; then
				echo "$([ $current_player == 1 ] && echo "$player1_name" || echo "$player2_name") wins!"
				game_over=true
			fi
		done

		((moves++))
		if ! $game_over && [ $moves -eq 9 ]; then
			echo "It's a tie!"
			game_over=true
		fi

		current_player=$((3 - current_player))

		save_game
	done
}

function save_game {
	echo "$player1_name $player2_name $current_player $game_over $moves" > "$save_file"
	for cell in "${board[@]}"; do
		echo "$cell"
	done >> "$save_file"

	if $game_over; then
		rm "$save_file"
	fi
}

function load_game {
	read -r player1_name player2_name current_player game_over moves < "$save_file"
	index=0
	while read -r cell; do
		board[$index]=$cell
		((index++))
	done < <(tail -n +2 "$save_file")

	if [[ ! "$current_player" =~ ^[12]$ ]] || [[ ! "$game_over" =~ ^(true|false)$ ]] || [[ ! "$moves" =~ ^[0-9]+$ ]] || [ "${#board[@]}" -ne 9 ]; then
		echo "Invalid save file data. Starting a new game."
		new_game
	else
		print_board
	fi
	play
}

function new_game {
	while true; do
		echo "Choose an opponent:"
		echo "1. Against another player"
		echo "2. Against AI"
		read -r -p "Enter your choice: " opponent_choice
		if [[ "$opponent_choice" =~ ^[12]$ ]]; then
			break
		else
			echo "Invalid choice. Please enter 1 or 2."
		fi
	done
	if [[ "$opponent_choice" == 1 ]]; then
		get_player_names
	else
		player1_name="Player"
		player2_name="AI"
	fi
	current_player=$((RANDOM % 2 + 1))
	echo "$([ $current_player == 1 ] && echo "$player1_name" || echo "$player2_name") starts the game!"
	sleep 2
	board=(1 2 3 4 5 6 7 8 9)
	print_board
	play
}

function start_game {
	if [ -f "$save_file" ]; then
		while true; do
			echo "Do you want to start a new game or continue the previously interrupted one?"
			echo "1. New game"
			echo "2. Continue previously interrupted game"
			read -r -p "Enter your choice: " choice
			if [[ "$choice" =~ ^[1-2]$ ]]; then
				case $choice in
					1)
						new_game
						break
						;;
					2)
						load_game
						break
						;;
				esac
			else
				echo "Invalid choice. Please enter 1 or 2."
				echo
			fi
		done
	else
		print_board
		echo "No saved game found. Press any key to start a new game!"
		read -n 1 -s -r
		new_game
	fi
}

start_game
