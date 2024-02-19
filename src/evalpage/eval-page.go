package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
	"time"
  "bufio"
	"golang.org/x/term"
)

func getTerminalWidth() int {
	width, _, err := term.GetSize(int(os.Stdout.Fd()))
	if err != nil {
		width = 80 // Default to 80 columns if the terminal size cannot be determined
	}
	return width
}

func drawTopBar(title string) {
	width := getTerminalWidth()
	currentTime := time.Now().Format("15:04:05")
	titleTimeStr := fmt.Sprintf("TITLE: %s 🕑 %s", title, currentTime)
	fmt.Println(titleTimeStr + strings.Repeat(" ", width-len(titleTimeStr)-1))
	fmt.Println(strings.Repeat("#", width))
}

func displayBlock(contents string) {
	// Placeholder for more sophisticated text wrapping and scrolling
	fmt.Println(contents)
}

func showPromptAndBottomBar(prompt string, options string, defaultOption string) {
    width, height, err := term.GetSize(int(os.Stdout.Fd()))
    if err != nil {
        width = 80  // Default width if terminal size cannot be determined
        height = 24 // Default height
    }

    // Calculate space for the prompt based on terminal width
    opts := strings.Split(options, ",")
    formattedOptions := make([]string, len(opts))
    for i, opt := range opts {
        formattedOptions[i] = fmt.Sprintf("(%s)%s", strings.ToUpper(string(opt[0])), opt[1:])
    }
    optionStr := fmt.Sprintf("> %s [%s]<%s>: _", prompt, strings.Join(formattedOptions, "/"), defaultOption)

    // Move the cursor to the bottom and print the bottom bar
    fmt.Printf("\033[%d;0H", height-2) // Adjusted to leave room for the prompt
    fmt.Println(strings.Repeat("#", width))

    // Move the cursor up one line to print the prompt above the bottom bar
    fmt.Printf("\033[%d;0H", height-1)
    fmt.Print(optionStr)

    // Wait for user input
    reader := bufio.NewReader(os.Stdin)
    input, _ := reader.ReadString('\n')
    input = strings.TrimSpace(input) // Remove newline character

    // Echo the input character
    fmt.Printf("You entered: %s\n", input)
}

func main() {
  fmt.Print("\033[H\033[2J")
	title := flag.String("title", "My page", "Title of the page")
	contents := flag.String("contents", "Big block of text goes here. Very long lines are truncated like this...", "Contents to display")
	prompt := flag.String("prompt", "Choose an option ", "Prompt text")
	options := flag.String("options", "Foo,fUm,Bar,Qux", "Comma-separated options")
	defaultOption := flag.String("default", "Qux", "Default option")

	flag.Parse()

	drawTopBar(*title)
	displayBlock(*contents)
	showPromptAndBottomBar(*prompt, *options, *defaultOption)
}
