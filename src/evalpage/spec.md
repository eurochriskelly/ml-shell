# Eval page

Eval page is a function which is run as follows from the terminal

./eval-page \
  --title "My page" \
  --contents "$LARGE_BLOCK_OF_TEXT" \
  --prompt "Choose an option " \
  --options "Foo,fUm,Bar,Qux" \
  --default "Qux"

It then prints on the terminal a message like this:

---
TITLE: My page                                           🕑 12:23:22 <- Always the top line (clear)
#################################################################### <- Always the second line
Big block of text goes here. Very long lines are truncated like t...









more text





There are more lines after this but we've reached the bottom of th...
#####################################################################  <- Always 2 from bottom
> Choose an option [(F)oo/f(U)m/(B)ar/(Q)ux]<Qux>: _                   <- Always the bottome line

NOTE: "---" indicates the top and bottom edges of the terminal

# Features

- The big block of text in the center should be scrollable and wrap/unwrap-able
