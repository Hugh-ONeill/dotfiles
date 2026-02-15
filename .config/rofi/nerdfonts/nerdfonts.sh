#!/usr/bin/env bash
# vim:ft=bash

# ══════════════════════════════════════════════════════════════════════════════
# Rofi Nerd Fonts Picker
# Categorized browser for Nerd Font icons
# ══════════════════════════════════════════════════════════════════════════════
DIR="$(dirname "$0")"
ROFI="rofi -dmenu -i -p Icons -theme ${DIR}/style.rasi"
nerd_font_file="/usr/lib/python3.14/site-packages/picker/data/nerd_font.csv"

# Fallback if path changes
[[ ! -f "$nerd_font_file" ]] && nerd_font_file=$(find /usr -name "nerd_font.csv" -path "*picker*" 2>/dev/null | head -1)

if [[ ! -f "$nerd_font_file" ]]; then
    notify-send "Nerd Fonts" "nerd_font.csv not found. Install rofimoji." -u critical
    exit 1
fi

# ══════════════════════════════════════════════════════════════════════════════
# Categories
# ══════════════════════════════════════════════════════════════════════════════

declare -A categories=(
    ["ascii"]="&	ASCII Symbols"
    ["extascii"]="©	Extended ASCII"
    ["arrows"]="→	Arrows"
    ["math"]="∑	Math Operators"
    ["boxdraw"]="╔	Box Drawing & Blocks"
    ["geometric"]="◆	Geometric Shapes"
    ["miscsym"]="☯	Misc Symbols"
    ["dingbats"]="✦	Dingbats"
    ["currency"]="€	Currency"
    ["typographic"]="…	Typographic"
    ["technical"]="⌘	Technical"
    ["legacy"]="🮕	Legacy Computing"
    ["cod"]="	Codicons (VS Code)"
    ["dev"]="	Devicons"
    ["fa"]="	Font Awesome"
    ["fae"]="	Font Awesome Ext"
    ["linux"]="	Linux Distros"
    ["md"]="󰦆	Material Design"
    ["oct"]="	Octicons (GitHub)"
    ["pl"]="	Powerline"
    ["ple"]="	Powerline Extra"
    ["pom"]="	Pomicons"
    ["seti"]="	Seti UI"
    ["weather"]="	Weather"
    ["iec"]="⏻	IEC Power"
    ["custom"]="	Custom"
)

# Category order for display
category_order=(ascii extascii arrows math boxdraw geometric miscsym dingbats currency typographic technical legacy cod dev fa fae linux md oct pl ple pom seti weather iec custom)

# ══════════════════════════════════════════════════════════════════════════════
# Functions
# ══════════════════════════════════════════════════════════════════════════════

show_all() {
    show_ascii_symbols
    show_ext_ascii_symbols
    show_arrows
    show_math
    show_box_drawing
    show_geometric
    show_misc_symbols
    show_dingbats
    show_currency
    show_typographic
    show_technical
    show_legacy
    sed 's/ /\t/' "$nerd_font_file"
}

show_categories() {
    {
        echo "⌕	Search All"
        for cat in "${category_order[@]}"; do
            echo "${categories[$cat]}"
        done
    } | $ROFI
}

get_category_prefix() {
    local selection="$1"
    for cat in "${!categories[@]}"; do
        if [[ "${categories[$cat]}" == "$selection" ]]; then
            echo "$cat"
            return
        fi
    done
}

show_ascii_symbols() {
    cat <<'SYMBOLS'
!	exclamation mark
"	quotation mark
#	number sign / hash
$	dollar sign
%	percent sign
&	ampersand
'	apostrophe
(	left parenthesis
)	right parenthesis
*	asterisk
+	plus sign
,	comma
-	hyphen / minus
.	period / full stop
/	slash / solidus
:	colon
;	semicolon
<	less-than sign
=	equals sign
>	greater-than sign
?	question mark
@	at sign
[	left square bracket
\	backslash
]	right square bracket
^	caret / circumflex
_	underscore
`	backtick / grave accent
{	left curly brace
|	vertical bar / pipe
}	right curly brace
~	tilde
SYMBOLS
}

show_ext_ascii_symbols() {
    cat <<'SYMBOLS'
¡	inverted exclamation
¢	cent sign
£	pound sign
¤	currency sign
¥	yen sign
¦	broken bar
§	section sign
¨	diaeresis
©	copyright sign
ª	feminine ordinal
«	left guillemet
¬	not sign
®	registered sign
¯	macron
°	degree sign
±	plus-minus sign
²	superscript two
³	superscript three
´	acute accent
µ	micro sign
¶	pilcrow / paragraph
·	middle dot
¸	cedilla
¹	superscript one
º	masculine ordinal
»	right guillemet
¼	one quarter
½	one half
¾	three quarters
¿	inverted question mark
×	multiplication sign
÷	division sign
SYMBOLS
}

show_arrows() {
    cat <<'SYMBOLS'
←	leftwards arrow
↑	upwards arrow
→	rightwards arrow
↓	downwards arrow
↔	left right arrow
↕	up down arrow
↖	north west arrow
↗	north east arrow
↘	south east arrow
↙	south west arrow
↚	leftwards arrow with stroke
↛	rightwards arrow with stroke
↜	leftwards wave arrow
↝	rightwards wave arrow
↞	leftwards two headed arrow
↟	upwards two headed arrow
↠	rightwards two headed arrow
↡	downwards two headed arrow
↢	leftwards arrow with tail
↣	rightwards arrow with tail
↤	leftwards arrow from bar
↥	upwards arrow from bar
↦	rightwards arrow from bar
↧	downwards arrow from bar
↨	up down arrow with base
↩	leftwards arrow with hook
↪	rightwards arrow with hook
↫	leftwards arrow with loop
↬	rightwards arrow with loop
↭	left right wave arrow
↮	left right arrow with stroke
↯	downwards zigzag arrow
↰	upwards arrow with tip left
↱	upwards arrow with tip right
↲	downwards arrow with tip left
↳	downwards arrow with tip right
↴	rightwards arrow with corner down
↵	downwards arrow with corner left
↶	anticlockwise top semicircle arrow
↷	clockwise top semicircle arrow
↺	anticlockwise open circle arrow
↻	clockwise open circle arrow
⇄	rightwards over leftwards arrow
⇅	upwards arrow left of downwards
⇆	leftwards over rightwards arrow
⇇	leftwards paired arrows
⇈	upwards paired arrows
⇉	rightwards paired arrows
⇊	downwards paired arrows
⇋	leftwards harpoon over rightwards
⇌	rightwards harpoon over leftwards
⇐	leftwards double arrow
⇑	upwards double arrow
⇒	rightwards double arrow
⇓	downwards double arrow
⇔	left right double arrow
⇕	up down double arrow
⇖	north west double arrow
⇗	north east double arrow
⇘	south east double arrow
⇙	south west double arrow
⇚	leftwards triple arrow
⇛	rightwards triple arrow
⇜	leftwards squiggle arrow
⇝	rightwards squiggle arrow
⇠	leftwards dashed arrow
⇡	upwards dashed arrow
⇢	rightwards dashed arrow
⇣	downwards dashed arrow
⟵	long leftwards arrow
⟶	long rightwards arrow
⟷	long left right arrow
⟸	long leftwards double arrow
⟹	long rightwards double arrow
⟺	long left right double arrow
➔	heavy wide-headed right arrow
➜	heavy round-tipped right arrow
➝	drafting point right arrow
➞	heavy right arrow
➟	dashed triangle-headed right arrow
➠	heavy dashed triangle-headed right
➡	black rightwards arrow
➢	three-d top-lighted right arrow
➣	three-d bottom-lighted right arrow
➤	black right arrowhead
➥	heavy black curved down right arrow
➦	heavy black curved up right arrow
➧	squat black right arrow
➨	heavy concave-pointed black right arrow
➩	right-shaded white right arrow
➪	left-shaded white right arrow
➫	back-tilted shadowed white right arrow
➬	front-tilted shadowed white right arrow
➭	heavy lower right-shadowed white right arrow
➮	heavy upper right-shadowed white right arrow
➯	notched lower right-shadowed white right arrow
➱	notched upper right-shadowed white right arrow
➲	circled heavy white right arrow
➳	white-feathered right arrow
➴	black-feathered south east arrow
➵	black-feathered right arrow
➶	black-feathered north east arrow
➷	heavy black-feathered south east arrow
➸	heavy black-feathered right arrow
➹	heavy black-feathered north east arrow
➺	teardrop-barbed right arrow
➻	heavy teardrop-shanked right arrow
➼	wedge-tailed right arrow
➽	heavy wedge-tailed right arrow
➾	open-outlined right arrow
⬅	leftwards black arrow
⬆	upwards black arrow
⬇	downwards black arrow
⬈	north east white arrow
⬉	north west white arrow
⬊	south east white arrow
⬋	south west white arrow
⬌	left right white arrow
⬍	up down white arrow
SYMBOLS
}

show_math() {
    cat <<'SYMBOLS'
∀	for all
∁	complement
∂	partial differential
∃	there exists
∄	there does not exist
∅	empty set
∆	increment / delta
∇	nabla / del
∈	element of
∉	not element of
∊	small element of
∋	contains as member
∌	does not contain
∍	small contains
∎	end of proof / QED
∏	n-ary product
∐	n-ary coproduct
∑	n-ary summation
−	minus sign
∓	minus-or-plus
∔	dot plus
∕	division slash
∖	set minus
∗	asterisk operator
∘	ring operator
∙	bullet operator
√	square root
∛	cube root
∜	fourth root
∝	proportional to
∞	infinity
∟	right angle
∠	angle
∡	measured angle
∢	spherical angle
∣	divides
∤	does not divide
∥	parallel to
∦	not parallel to
∧	logical and
∨	logical or
∩	intersection
∪	union
∫	integral
∬	double integral
∭	triple integral
∮	contour integral
∯	surface integral
∰	volume integral
∱	clockwise integral
∲	clockwise contour integral
∳	anticlockwise contour integral
∴	therefore
∵	because
∶	ratio
∷	proportion
∼	tilde operator
∽	reversed tilde
≀	wreath product
≂	minus tilde
≃	asymptotically equal
≅	approximately equal
≈	almost equal to
≉	not almost equal
≊	almost equal or equal
≌	all equal to
≍	equivalent to
≎	geometrically equivalent
≏	difference between
≐	approaches the limit
≑	geometrically equal
≒	approximately equal or image
≓	image or approximately equal
≔	colon equals
≕	equals colon
≜	delta equal to
≝	equal by definition
≟	questioned equal to
≠	not equal to
≡	identical to
≢	not identical to
≤	less-than or equal
≥	greater-than or equal
≦	less-than over equal
≧	greater-than over equal
≨	less-than but not equal
≩	greater-than but not equal
≪	much less-than
≫	much greater-than
≮	not less-than
≯	not greater-than
≰	not less-than or equal
≱	not greater-than or equal
≲	less-than or equivalent
≳	greater-than or equivalent
⊂	subset of
⊃	superset of
⊄	not a subset of
⊅	not a superset of
⊆	subset of or equal
⊇	superset of or equal
⊈	not subset or equal
⊉	not superset or equal
⊊	subset not equal
⊋	superset not equal
⊕	circled plus / direct sum
⊖	circled minus
⊗	circled times
⊘	circled division slash
⊙	circled dot
⊚	circled ring
⊛	circled asterisk
⊜	circled equals
⊝	circled dash
⊞	squared plus
⊟	squared minus
⊠	squared times
⊡	squared dot
⊥	perpendicular / up tack
⊦	assertion
⊧	models
⊨	true
⊩	forces
⊪	triple vertical bar right
⊬	does not prove
⊭	not true
⊮	does not force
⊰	precedes under relation
⊱	succeeds under relation
⋀	n-ary logical and
⋁	n-ary logical or
⋂	n-ary intersection
⋃	n-ary union
⋄	diamond operator
⋅	dot operator
⋆	star operator
⋇	division times
⋈	bowtie
⋉	left normal factor semidirect
⋊	right normal factor semidirect
⋮	vertical ellipsis
⋯	midline horizontal ellipsis
⋰	up right diagonal ellipsis
⋱	down right diagonal ellipsis
⟂	perpendicular
⟨	math left angle bracket
⟩	math right angle bracket
SYMBOLS
}

show_box_drawing() {
    cat <<'SYMBOLS'
─	light horizontal
━	heavy horizontal
│	light vertical
┃	heavy vertical
┄	light triple dash horizontal
┅	heavy triple dash horizontal
┆	light triple dash vertical
┇	heavy triple dash vertical
┈	light quadruple dash horizontal
┉	heavy quadruple dash horizontal
┊	light quadruple dash vertical
┋	heavy quadruple dash vertical
┌	light down and right
┍	down light and right heavy
┎	down heavy and right light
┏	heavy down and right
┐	light down and left
┑	down light and left heavy
┒	down heavy and left light
┓	heavy down and left
└	light up and right
┕	up light and right heavy
┖	up heavy and right light
┗	heavy up and right
┘	light up and left
┙	up light and left heavy
┚	up heavy and left light
┛	heavy up and left
├	light vertical and right
┣	heavy vertical and right
┤	light vertical and left
┫	heavy vertical and left
┬	light down and horizontal
┳	heavy down and horizontal
┴	light up and horizontal
┻	heavy up and horizontal
┼	light vertical and horizontal
╋	heavy vertical and horizontal
═	double horizontal
║	double vertical
╔	double down and right
╗	double down and left
╚	double up and right
╝	double up and left
╠	double vertical and right
╣	double vertical and left
╦	double down and horizontal
╩	double up and horizontal
╬	double vertical and horizontal
╭	light arc down and right
╮	light arc down and left
╯	light arc up and left
╰	light arc up and right
╱	light diagonal upper right
╲	light diagonal upper left
╳	light diagonal cross
╴	light left
╵	light up
╶	light right
╷	light down
╸	heavy left
╹	heavy up
╺	heavy right
╻	heavy down
▀	upper half block
▁	lower one eighth block
▂	lower one quarter block
▃	lower three eighths block
▄	lower half block
▅	lower five eighths block
▆	lower three quarters block
▇	lower seven eighths block
█	full block
▉	left seven eighths block
▊	left three quarters block
▋	left five eighths block
▌	left half block
▍	left three eighths block
▎	left one quarter block
▏	left one eighth block
▐	right half block
░	light shade
▒	medium shade
▓	dark shade
▔	upper one eighth block
▕	right one eighth block
▖	quadrant lower left
▗	quadrant lower right
▘	quadrant upper left
▙	quadrant upper left and lower
▚	quadrant upper left and lower right
▛	quadrant upper left and upper right and lower left
▜	quadrant upper left and upper right and lower right
▝	quadrant upper right
▞	quadrant upper right and lower left
▟	quadrant upper right and lower left and lower right
SYMBOLS
}

show_geometric() {
    cat <<'SYMBOLS'
■	black square
□	white square
▢	white square with rounded corners
▣	white square containing black small square
▤	square with horizontal fill
▥	square with vertical fill
▦	square with orthogonal crosshatch
▧	square with upper left to lower right fill
▨	square with upper right to lower left fill
▩	square with diagonal crosshatch
▪	black small square
▫	white small square
▬	black rectangle
▭	white rectangle
▮	black vertical rectangle
▯	white vertical rectangle
▰	black parallelogram
▱	white parallelogram
▲	black up-pointing triangle
△	white up-pointing triangle
▴	black up-pointing small triangle
▵	white up-pointing small triangle
▶	black right-pointing triangle
▷	white right-pointing triangle
▸	black right-pointing small triangle
▹	white right-pointing small triangle
►	black right-pointing pointer
▻	white right-pointing pointer
▼	black down-pointing triangle
▽	white down-pointing triangle
▾	black down-pointing small triangle
▿	white down-pointing small triangle
◀	black left-pointing triangle
◁	white left-pointing triangle
◂	black left-pointing small triangle
◃	white left-pointing small triangle
◄	black left-pointing pointer
◅	white left-pointing pointer
◆	black diamond
◇	white diamond
◈	white diamond containing black small diamond
◉	fisheye
◊	lozenge
○	white circle
◌	dotted circle
◍	circle with vertical fill
◎	bullseye
●	black circle
◐	circle with left half black
◑	circle with right half black
◒	circle with lower half black
◓	circle with upper half black
◔	circle with upper right quadrant black
◕	circle with all but upper left quadrant black
◖	left half black circle
◗	right half black circle
◘	inverse bullet
◙	inverse white circle
◚	upper half inverse white circle
◛	lower half inverse white circle
◜	upper left quadrant circular arc
◝	upper right quadrant circular arc
◞	lower right quadrant circular arc
◟	lower left quadrant circular arc
◠	upper half circle
◡	lower half circle
◢	black lower right triangle
◣	black lower left triangle
◤	black upper left triangle
◥	black upper right triangle
◦	white bullet
◧	square with left half black
◨	square with right half black
◩	square with upper left diagonal half black
◪	square with lower right diagonal half black
◫	white square with vertical bisecting line
◬	white up-pointing triangle with dot
◭	up-pointing triangle with left half black
◮	up-pointing triangle with right half black
◯	large circle
⬠	white pentagon
⬡	white hexagon
⬢	black hexagon
⬣	horizontal black hexagon
⬤	black large circle
⬥	black medium diamond
⬦	white medium diamond
⬧	black medium lozenge
⬨	white medium lozenge
⬩	black small diamond
⬪	white small diamond
⬬	black very small square
⬭	white very small square
⬮	black pentagon
SYMBOLS
}

show_misc_symbols() {
    cat <<'SYMBOLS'
☀	black sun with rays
☁	cloud
☂	umbrella
☃	snowman
☄	comet
★	black star
☆	white star
☇	lightning
☈	thunderstorm
☉	sun
☎	black telephone
☏	white telephone
☐	ballot box
☑	ballot box with check
☒	ballot box with x
☔	umbrella with rain drops
☕	hot beverage
☘	shamrock
☙	reversed rotated floral heart bullet
☚	black left pointing index
☛	black right pointing index
☜	white left pointing index
☝	white up pointing index
☞	white right pointing index
☟	white down pointing index
☠	skull and crossbones
☡	caution sign
☢	radioactive sign
☣	biohazard sign
☤	caduceus
☥	ankh
☦	orthodox cross
☧	chi rho
☨	cross of lorraine
☩	cross of jerusalem
☪	star and crescent
☫	farsi symbol
☬	adi shakti
☭	hammer and sickle
☮	peace symbol
☯	yin yang
☰	trigram heaven
☱	trigram lake
☲	trigram fire
☳	trigram thunder
☴	trigram wind
☵	trigram water
☶	trigram mountain
☷	trigram earth
☸	wheel of dharma
☹	white frowning face
☺	white smiling face
☻	black smiling face
☼	sun with face
☽	first quarter moon
☾	last quarter moon
☿	mercury
♀	female sign
♁	earth
♂	male sign
♃	jupiter
♄	saturn
♅	uranus
♆	neptune
♇	pluto
♈	aries
♉	taurus
♊	gemini
♋	cancer
♌	leo
♍	virgo
♎	libra
♏	scorpius
♐	sagittarius
♑	capricorn
♒	aquarius
♓	pisces
♔	white chess king
♕	white chess queen
♖	white chess rook
♗	white chess bishop
♘	white chess knight
♙	white chess pawn
♚	black chess king
♛	black chess queen
♜	black chess rook
♝	black chess bishop
♞	black chess knight
♟	black chess pawn
♠	black spade suit
♡	white heart suit
♢	white diamond suit
♣	black club suit
♤	white spade suit
♥	black heart suit
♦	black diamond suit
♧	white club suit
♨	hot springs
♩	quarter note
♪	eighth note
♫	beamed eighth notes
♬	beamed sixteenth notes
♭	music flat sign
♮	music natural sign
♯	music sharp sign
⚀	die face-1
⚁	die face-2
⚂	die face-3
⚃	die face-4
⚄	die face-5
⚅	die face-6
⚐	white flag
⚑	black flag
⚒	hammer and pick
⚓	anchor
⚔	crossed swords
⚕	staff of aesculapius
⚖	scales
⚗	alembic
⚘	flower
⚙	gear
⚚	staff of hermes
⚛	atom symbol
⚜	fleur-de-lis
⚝	outlined white star
⚠	warning sign
⚡	high voltage sign
⚪	medium white circle
⚫	medium black circle
⚬	medium small white circle
⚭	marriage symbol
⚮	divorce symbol
⚯	unmarried partnership
⚰	coffin
⚱	funeral urn
⚲	neuter
SYMBOLS
}

show_dingbats() {
    cat <<'SYMBOLS'
✁	upper blade scissors
✂	black scissors
✃	lower blade scissors
✄	white scissors
✆	telephone location sign
✇	tape drive
✈	airplane
✉	envelope
✊	raised fist
✋	raised hand
✌	victory hand
✍	writing hand
✎	lower right pencil
✏	pencil
✐	upper right pencil
✑	white nib
✒	black nib
✓	check mark
✔	heavy check mark
✕	multiplication x
✖	heavy multiplication x
✗	ballot x
✘	heavy ballot x
✙	outlined greek cross
✚	heavy greek cross
✛	open centre cross
✜	heavy open centre cross
✝	latin cross
✞	shadowed white latin cross
✟	outlined latin cross
✠	maltese cross
✡	star of david
✢	four teardrop-spoked asterisk
✣	four balloon-spoked asterisk
✤	heavy four balloon-spoked asterisk
✥	four club-spoked asterisk
✦	black four pointed star
✧	white four pointed star
✩	stress outlined white star
✪	circled white star
✫	open centre black star
✬	black centre white star
✭	outlined black star
✮	heavy outlined black star
✯	pinwheel star
✰	shadowed white star
✱	heavy asterisk
✲	open centre asterisk
✳	eight spoked asterisk
✴	eight pointed black star
✵	eight pointed pinwheel star
✶	six pointed black star
✷	eight pointed rectilinear black star
✸	heavy eight pointed rectilinear black star
✹	twelve pointed black star
✺	sixteen pointed asterisk
✻	teardrop-spoked asterisk
✼	open centre teardrop-spoked asterisk
✽	heavy teardrop-spoked asterisk
✾	six petalled black and white florette
✿	black florette
❀	white florette
❁	eight petalled outlined black florette
❂	circled open centre eight pointed star
❃	heavy teardrop-spoked pinwheel asterisk
❄	heavy chevron snowflake
❅	rotated heavy chevron snowflake
❆	heavy sparkle
❇	sparkle
❈	heavy sparkle
❉	balloon-spoked asterisk
❊	eight teardrop-spoked propeller asterisk
❋	heavy eight teardrop-spoked propeller asterisk
❌	cross mark
❍	shadowed white circle
❎	negative squared cross mark
❏	upper right drop-shadowed white square
❐	upper right shadowed white square
❑	lower right shadowed white square
❒	upper right shadowed white square
❖	black diamond minus white x
❗	heavy exclamation mark
❛	heavy single turned comma quote
❜	heavy single comma quote
❝	heavy double turned comma quote
❞	heavy double comma quote
❡	reversed rotated floral heart bullet
❢	rotated heavy black heart bullet
❣	heavy heart exclamation mark
❤	heavy black heart
❥	rotated heavy black heart bullet
❦	floral heart
❧	rotated floral heart bullet
SYMBOLS
}

show_currency() {
    cat <<'SYMBOLS'
¢	cent sign
£	pound sign
¤	currency sign
¥	yen / yuan sign
€	euro sign
₠	euro-currency sign
₡	colon sign
₢	cruzeiro sign
₣	french franc sign
₤	lira sign
₥	mill sign
₦	naira sign
₧	peseta sign
₨	rupee sign
₩	won sign
₪	new sheqel sign
₫	dong sign
₭	kip sign
₮	tugrik sign
₯	drachma sign
₰	german penny sign
₱	peso sign
₲	guarani sign
₳	austral sign
₴	hryvnia sign
₵	cedi sign
₶	livre tournois sign
₷	spesmilo sign
₸	tenge sign
₹	indian rupee sign
₺	turkish lira sign
₻	nordic mark sign
₼	manat sign
₽	ruble sign
₾	lari sign
₿	bitcoin sign
﷼	rial sign
SYMBOLS
}

show_typographic() {
    cat <<'SYMBOLS'
–	en dash
—	em dash
‒	figure dash
―	horizontal bar
'	left single quotation mark
'	right single quotation mark
‚	single low-9 quotation mark
‛	single high-reversed-9 quotation mark
"	left double quotation mark
"	right double quotation mark
„	double low-9 quotation mark
‟	double high-reversed-9 quotation mark
†	dagger
‡	double dagger
•	bullet
‣	triangular bullet
‥	two dot leader
…	horizontal ellipsis
‧	hyphenation point
‰	per mille sign
‱	per ten thousand sign
′	prime
″	double prime
‴	triple prime
‵	reversed prime
‶	reversed double prime
‷	reversed triple prime
‹	single left-pointing angle quote
›	single right-pointing angle quote
‽	interrobang
⁂	asterism
⁃	hyphen bullet
⁄	fraction slash
⁅	left square bracket with quill
⁆	right square bracket with quill
⁊	turned capital f
⁋	reversed pilcrow sign
⁌	black leftwards bullet
⁍	black rightwards bullet
⁎	low asterisk
⁏	two dot punctuation
⁐	four dot punctuation
⁑	two dot punctuation
™	trade mark sign
℠	service mark
℗	sound recording copyright
℃	degree celsius
℉	degree fahrenheit
№	numero sign
℮	estimated symbol
SYMBOLS
}

show_technical() {
    cat <<'SYMBOLS'
⌀	diameter sign
⌁	electric arrow
⌂	house
⌃	up arrowhead (control)
⌄	down arrowhead
⌅	projective
⌆	perspective
⌇	wavy line
⌈	left ceiling
⌉	right ceiling
⌊	left floor
⌋	right floor
⌐	reversed not sign
⌑	square lozenge
⌒	arc
⌗	viewdata square
⌘	place of interest / command
⌙	turned not sign
⌚	watch
⌛	hourglass
⌜	top left corner
⌝	top right corner
⌞	bottom left corner
⌟	bottom right corner
⌨	keyboard
⌫	erase to the left / delete
⌬	benzene ring
⎈	helm symbol
⎋	broken circle with northwest arrow / escape
⎌	undo symbol
⎍	monostable symbol
⎎	hysteresis symbol
⏎	return symbol
⏏	eject symbol
⏐	vertical line extension
⏚	earth ground
⏛	fuse
⏢	trapezium
⏣	benzene ring with circle
⏤	straightness
⏥	flatness
⏦	ac current
⏧	electrical intersection
⏩	black right-pointing double triangle
⏪	black left-pointing double triangle
⏫	black up-pointing double triangle
⏬	black down-pointing double triangle
⏭	black right-pointing double triangle with bar
⏮	black left-pointing double triangle with bar
⏯	black right-pointing triangle with double bar
⏰	alarm clock
⏱	stopwatch
⏲	timer clock
⏳	hourglass with flowing sand
⏴	black medium left-pointing triangle
⏵	black medium right-pointing triangle
⏶	black medium up-pointing triangle
⏷	black medium down-pointing triangle
⏸	double vertical bar / pause
⏹	black square for stop
⏺	black circle for record
⏻	power symbol
⏼	power on-off symbol
⏽	power on symbol
⏾	power sleep symbol
SYMBOLS
}

show_legacy() {
    cat <<'SYMBOLS'
🬀	block sextant-1
🬁	block sextant-2
🬂	block sextant-12
🬃	block sextant-3
🬄	block sextant-13
🬅	block sextant-23
🬆	block sextant-123
🬇	block sextant-4
🬈	block sextant-14
🬉	block sextant-24
🬊	block sextant-124
🬋	block sextant-34
🬌	block sextant-134
🬍	block sextant-234
🬎	block sextant-1234
🬏	block sextant-5
🬐	block sextant-15
🬑	block sextant-25
🬒	block sextant-125
🬓	block sextant-35
🬔	block sextant-235
🬕	block sextant-1235
🬖	block sextant-45
🬗	block sextant-145
🬘	block sextant-245
🬙	block sextant-1245
🬚	block sextant-345
🬛	block sextant-1345
🬜	block sextant-2345
🬝	block sextant-12345
🬞	block sextant-6
🬟	block sextant-16
🬠	block sextant-26
🬡	block sextant-126
🬢	block sextant-36
🬣	block sextant-136
🬤	block sextant-236
🬥	block sextant-1236
🬦	block sextant-46
🬧	block sextant-146
🬨	block sextant-1246
🬩	block sextant-346
🬪	block sextant-1346
🬫	block sextant-2346
🬬	block sextant-12346
🬭	block sextant-56
🬮	block sextant-156
🬯	block sextant-256
🬰	block sextant-1256
🬱	block sextant-356
🬲	block sextant-1356
🬳	block sextant-2356
🬴	block sextant-12356
🬵	block sextant-456
🬶	block sextant-1456
🬷	block sextant-2456
🬸	block sextant-12456
🬹	block sextant-3456
🬺	block sextant-13456
🬻	block sextant-23456
🬼	diagonal lower middle left to lower centre
🬽	diagonal lower middle left to lower right
🬾	diagonal upper middle left to lower centre
🬿	diagonal upper middle left to lower right
🭀	diagonal upper left to lower centre
🭁	diagonal upper middle left to upper centre
🭂	diagonal upper middle left to upper right
🭃	diagonal lower middle left to upper centre
🭄	diagonal lower middle left to upper right
🭅	diagonal lower left to upper centre
🭆	diagonal lower middle left to upper middle right
🭇	diagonal lower centre to lower middle right
🭈	diagonal lower left to lower middle right
🭉	diagonal lower centre to upper middle right
🭊	diagonal lower left to upper middle right
🭋	diagonal lower centre to upper right
🭌	diagonal upper centre to upper middle right
🭍	diagonal upper left to upper middle right
🭎	diagonal upper centre to lower middle right
🭏	diagonal upper left to lower middle right
🭐	diagonal upper centre to lower right
🭑	diagonal upper middle left to lower middle right
🭒	upper right diagonal lower middle left to lower centre
🭓	upper right diagonal lower middle left to lower right
🭔	upper right diagonal upper middle left to lower centre
🭕	upper right diagonal upper middle left to lower right
🭖	upper right diagonal upper left to lower centre
🭗	upper left diagonal upper middle left to upper centre
🭘	upper left diagonal upper middle left to upper right
🭙	upper left diagonal lower middle left to upper centre
🭚	upper left diagonal lower middle left to upper right
🭛	upper left diagonal lower left to upper centre
🭜	upper left diagonal lower middle left to upper middle right
🭝	upper left diagonal lower centre to lower middle right
🭞	upper left diagonal lower left to lower middle right
🭟	upper left diagonal lower centre to upper middle right
🭠	upper left diagonal lower left to upper middle right
🭡	upper left diagonal lower centre to upper right
🭢	upper right diagonal upper centre to upper middle right
🭣	upper right diagonal upper left to upper middle right
🭤	upper right diagonal upper centre to lower middle right
🭥	upper right diagonal upper left to lower middle right
🭦	upper right diagonal upper centre to lower right
🭧	upper right diagonal upper middle left to lower middle right
🭨	upper+right+lower triangular three quarters block
🭩	left+lower+right triangular three quarters block
🭪	upper+left+lower triangular three quarters block
🭫	left+upper+right triangular three quarters block
🭬	left triangular one quarter block
🭭	upper triangular one quarter block
🭮	right triangular one quarter block
🭯	lower triangular one quarter block
🭰	vertical one eighth block-2
🭱	vertical one eighth block-3
🭲	vertical one eighth block-4
🭳	vertical one eighth block-5
🭴	vertical one eighth block-6
🭵	vertical one eighth block-7
🭶	horizontal one eighth block-2
🭷	horizontal one eighth block-3
🭸	horizontal one eighth block-4
🭹	horizontal one eighth block-5
🭺	horizontal one eighth block-6
🭻	horizontal one eighth block-7
🭼	left and lower one eighth block
🭽	left and upper one eighth block
🭾	right and upper one eighth block
🭿	right and lower one eighth block
🮀	upper and lower one eighth block
🮁	horizontal one eighth block-1358
🮂	upper one quarter block
🮃	upper three eighths block
🮄	upper five eighths block
🮅	upper three quarters block
🮆	upper seven eighths block
🮇	right one quarter block
🮈	right three eighths block
🮉	right five eighths block
🮊	right three quarters block
🮋	right seven eighths block
🮌	left half medium shade
🮍	right half medium shade
🮎	upper half medium shade
🮏	lower half medium shade
🮐	inverse medium shade
🮑	upper half block and lower half inverse medium shade
🮒	upper half inverse medium shade and lower half block
🮔	left half inverse medium shade and right half block
🮕	checker board fill
🮖	inverse checker board fill
🮗	heavy horizontal fill
🮘	upper left to lower right fill
🮙	upper right to lower left fill
🮚	upper and lower triangular half block
🮛	left and right triangular half block
🮜	upper left triangular medium shade
🮝	upper right triangular medium shade
🮞	lower right triangular medium shade
🮟	lower left triangular medium shade
🮠	diagonal box upper centre to middle left
🮡	diagonal box upper centre to middle right
🮢	diagonal box middle left to lower centre
🮣	diagonal box middle right to lower centre
🮤	diagonal box upper centre to middle left to lower centre
🮥	diagonal box upper centre to middle right to lower centre
🮦	diagonal box middle left to lower centre to middle right
🮧	diagonal box middle left to upper centre to middle right
🮨	diagonal box upper centre to middle left and middle right to lower centre
🮩	diagonal box upper centre to middle right and middle left to lower centre
🮪	diagonal box upper centre to middle right to lower centre to middle left
🮫	diagonal box upper centre to middle left to lower centre to middle right
🮬	diagonal box middle left to upper centre to middle right to lower centre
🮭	diagonal box middle right to upper centre to middle left to lower centre
🮮	diagonal box diamond
🮯	horizontal with vertical stroke
🮰	arrowhead-shaped pointer
🮱	inverse check mark
🮲	left half running man
🮳	right half running man
🮴	inverse downwards arrow with tip leftwards
🮵	leftwards arrow and upper and lower one eighth block
🮶	rightwards arrow and upper and lower one eighth block
🮷	downwards arrow and right one eighth block
🮸	upwards arrow and right one eighth block
🮹	left half folder
🮺	right half folder
🮻	voided greek cross
🮼	right open squared dot
🮽	negative diagonal cross
🮾	negative diagonal middle right to lower centre
🮿	negative diagonal diamond
🯀	white heavy saltire with rounded corners
🯁	left third pointing index
🯂	middle third pointing index
🯃	right third pointing index
🯄	negative squared question mark
🯅	stick figure
🯆	stick figure with arms raised
🯇	stick figure leaning left
🯈	stick figure leaning right
🯉	stick figure with dress
🯊	white up-pointing chevron
🯋	white cross mark
🯌	raised small left square bracket
🯍	black small up-pointing chevron
🯎	left two thirds block
🯏	left one third block
🯐	diagonal box middle right to lower left
🯑	diagonal box upper right to middle left
🯒	diagonal box upper left to middle right
🯓	diagonal box middle left to lower right
🯔	diagonal box upper left to lower centre
🯕	diagonal box upper centre to lower right
🯖	diagonal box upper right to lower centre
🯗	diagonal box upper centre to lower left
🯘	diagonal box upper left to middle centre to upper right
🯙	diagonal box upper right to middle centre to lower right
🯚	diagonal box lower left to middle centre to lower right
🯛	diagonal box upper left to middle centre to lower left
🯜	diagonal box upper left to lower centre to upper right
🯝	diagonal box upper right to middle left to lower right
🯞	diagonal box lower left to upper centre to lower right
🯟	diagonal box upper left to middle right to lower left
🯠	top justified lower half white circle
🯡	right justified left half white circle
🯢	bottom justified upper half white circle
🯣	left justified right half white circle
🯤	upper centre one quarter block
🯥	lower centre one quarter block
🯦	middle left one quarter block
🯧	middle right one quarter block
🯨	top justified lower half black circle
🯩	right justified left half black circle
🯪	bottom justified upper half black circle
🯫	left justified right half black circle
🯬	top right lower left quarter black circle
🯭	bottom left upper right quarter black circle
🯮	bottom right upper left quarter black circle
🯯	top left lower right quarter black circle
🯰	segmented digit zero
🯱	segmented digit one
🯲	segmented digit two
🯳	segmented digit three
🯴	segmented digit four
🯵	segmented digit five
🯶	segmented digit six
🯷	segmented digit seven
🯸	segmented digit eight
🯹	segmented digit nine
SYMBOLS
}

show_icons() {
    local prefix="$1"
    case "$prefix" in
        ascii)      show_ascii_symbols | $ROFI ;;
        extascii)   show_ext_ascii_symbols | $ROFI ;;
        arrows)     show_arrows | $ROFI ;;
        math)       show_math | $ROFI ;;
        boxdraw)    show_box_drawing | $ROFI ;;
        geometric)  show_geometric | $ROFI ;;
        miscsym)    show_misc_symbols | $ROFI ;;
        dingbats)   show_dingbats | $ROFI ;;
        currency)   show_currency | $ROFI ;;
        typographic) show_typographic | $ROFI ;;
        technical)  show_technical | $ROFI ;;
        legacy)     show_legacy | $ROFI ;;
        *)          grep " ${prefix}-" "$nerd_font_file" | sed 's/ /\t/' | $ROFI ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════════

while true; do
    category=$(show_categories)
    [[ -z "$category" ]] && exit 0

    if [[ "$category" == *"Search All"* ]]; then
        selected=$(show_all | $ROFI)
        [[ -z "$selected" ]] && continue
    else
        prefix=$(get_category_prefix "$category")
        [[ -z "$prefix" ]] && exit 0

        selected=$(show_icons "$prefix")
        [[ -z "$selected" ]] && continue
    fi

    # extract just the icon (first field, tab-separated)
    icon="${selected%%	*}"

    # Copy to clipboard
    echo -n "$icon" | wl-copy
    notify-send "Nerd Fonts" "Copied: $icon" -t 1500
    exit 0
done
