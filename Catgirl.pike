// Catgirl Class
string name;
string hair_color;
string eye_color;
string tail_type;
string ear_style;
string outfit;
string personality;
string mood = "happy";
string title = "Stray";
string occupation;
string hobby;
string favorite_food;
int level = 1;
int experience = 0;
mapping(string:int) stats = ([]);


void calculate_stats() {
  stats["cuteness"] = 50 + random(20);
  stats["agility"] = 50 + random(20);
  if (outfit == "maid outfit" || outfit == "gothic lolita dress") 
    stats["cuteness"] += 15;
  if (outfit == "combat suit") 
    stats["agility"] += 15;
}

void gain_xp(int amount) {
  experience += amount;
  if (experience >= 100) {
  level++;
  experience = 0;
  stats["cuteness"] += 5 + random(5);
  stats["agility"] += 5 + random(5);
  if (level == 2) title = "Elite Feline";
    else if (level >= 3) title = "Supreme Neko";
    write("\n✨ " + name + " reached Level " + 
      level + " [" + title + "]! ✨\n");
   }
 }

 int use_special_move(string type) {
   write(name + " uses a special technique!\n");
   switch(occupation) {
     case "programmer": return 15 + (level * 2);
     case "cafe maid": return 20;
     case "bounty hunter": return 18;
     default: return 10;
    }
 }

 void compete(object opponent, string type) {
   int my_roll = stats[type] + random(20) + (random(100) < 30 ? use_special_move(type) : 0);
   int op_roll = opponent->stats[type] + random(20) + (random(100) < 30 ? opponent->use_special_move(type) : 0);

   if (my_roll > op_roll) {
     write(name + " wins the " + type + " competition!\n");
     gain_xp(50);
     mood = "triumphant";
     } else {
       write(opponent->name + " wins!\n");
       gain_xp(10);
       mood = "grumpy";
     }
  }

 void affection_compete(object partner) {
   write(name + " and " + partner->name + " share a sweet moment.\n");
   gain_xp(30);
   partner->gain_xp(30);
   mood = "blissful";
   partner->mood = "blissful";
 }

string _sprintf() {
  return sprintf("Catgirl(%s, Lv %d, %s)", name, level, title);
}

void print_info() {
    write("\n============================================\n");
    write("          CHARACTER SHEET: " + upper_case(name) + "          \n");
    write("============================================\n");
    write(" [Identity]           [Appearance]\n");
    write(" Title: " + title + "          Hair: " + hair_color + "\n");
    write(" Occupation: " + occupation + "    Eyes: " + eye_color + "\n");
    write(" Hobby: " + hobby + "            Ears: " + ear_style + "\n");
    write(" Food: " + favorite_food + "        Tail: " + tail_type + "\n");
    write(" Personality: " + personality + "\n");
    write("--------------------------------------------\n");
    write(" [Progression]        [Combat Specs]\n");
    write(" Level: " + level + "             Cuteness: " + stats["cuteness"] + "\n");
    write(" XP: " + experience + "/100        Agility: " + stats["agility"] + "\n");
    write(" Mood: " + mood + "\n");
    write("============================================\n\n");
}
 
// Controller function for the group
void socialize_group(array(object) group) {
    array(object) grumpy = filter(group, lambda(object c) { return c->mood == "grumpy"; });
    if (sizeof(grumpy) >= 2) {
        write("Reconciling " + grumpy[0]->name + " and " + grumpy[1]->name + "...\n");
        grumpy[0]->affection_compete(grumpy[1]);
    }
}

void greet() {
    write("Meow! I'm " + name + ". I was just " + hobby + ". Care to join me?\n");
}

void talk_to(object other_catgirl) {
    write(name + " approaches " + other_catgirl->name + ".\n");

    switch(personality) {
        case "tsundere":
            write(name + " huffs: 'It's not like I wanted to talk to a " + other_catgirl->occupation + " like you, baka!'\n");
            mood = "blushing";
            break;
        case "shy":
            write(name + " hides her " + tail_type + " tail and whispers: 'U-um, hello... do you like " + hobby + " too?'\n");
            mood = "nervous";
            break;
        case "mischievous":
            write(name + " giggles and tries to swipe at " + other_catgirl->name + "'s " + other_catgirl->ear_style + " ears!\n");
            mood = "playful";
            break;
        case "cheerful":
            write(name + " beams: 'Hi hi! Your " + other_catgirl->hair_color + " hair looks so pretty today!'\n");
            mood = "happy";
            break;
        case "kuudere":
            write(name + " stares blankly. '...Hello. I am going back to " + hobby + " now.'\n");
            mood = "indifferent";
            break;
        default:
            write(name + " waves: 'Nya! Nice to meet a fellow " + other_catgirl->occupation + "!'\n");
            mood = "friendly";
            break;
    }
}

void create() {
    array(string) names = ({
        "Luna", "Mika", "Yuki", "Neko", "Aiko", "Sora", "Hana", 
        "Mitsuki", "Nyx", "Bell", "Kiki", "Mocha", "Truffle"
    });
        
    array(string) hair_colors = ({
        "black", "brown", "blonde", "silver", "pink", "white", 
        "lavender", "midnight blue", "calico", "crimson"
    });
        
    array(string) eye_colors = ({
        "blue", "green", "amber", "violet", "gold", "red", 
        "heterochromia (blue/yellow)", "emerald", "aquamarine"
    });

    array(string) tail_types = ({
        "long and fluffy", "short bobtail", "sleek and thin", 
        "curled", "twin tails", "lion-like"
    });

    array(string) ear_styles = ({
        "pointed", "folded", "tufted", "extra fluffy", "droopy"
    });
    
    array(string) outfits = ({
        "maid outfit", "school uniform", "hoodie", "lingerie",
        "kimono", "combat suit", "gothic lolita dress", "cyberpunk techwear",
        "oversized sweater", "detective trench coat"
    });
    
    array(string) personalities = ({
        "playful", "shy", "mischievous", "cheerful", "tsundere", 
        "curious", "kuudere", "energetic", "stoic", "clumsy"
    });
        
    array(string) occupations = ({
        "cafe maid", "student", "programmer", "street performer",
        "poet", "shop assistant", "exotic dancer", "courtesan",
        "shrine maiden", "bounty hunter", "librarian", "alchemist"
    });
    
    array(string) hobbies = ({
        "chasing laser pointers", "reading 19th century French poetry",
        "playing video games", "napping in sunny spots",
        "collecting shiny objects", "baking pastries", "stargazing",
        "sharpening claws", "learning forbidden magic", "cosplaying"
    });

    array(string) foods = ({
        "taiyaki", "tuna sashimi", "strawberry crepes", "milk tea",
        "roasted salmon", "catnip brownies"
    });

    // Random Assignment
    name = names[random(sizeof(names))];
    hair_color = hair_colors[random(sizeof(hair_colors))];
    eye_color = eye_colors[random(sizeof(eye_colors))];
    tail_type = tail_types[random(sizeof(tail_types))];
    ear_style = ear_styles[random(sizeof(ear_styles))];
    outfit = outfits[random(sizeof(outfits))];
    personality = personalities[random(sizeof(personalities))];
    mood = "neutral";
    occupation = occupations[random(sizeof(occupations))];
    hobby = hobbies[random(sizeof(hobbies))];
    favorite_food = foods[random(sizeof(foods))];
    calculate_stats();
}
