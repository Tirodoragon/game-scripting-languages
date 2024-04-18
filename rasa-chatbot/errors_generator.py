import random


def substitution_error(word):
    nearby_chars = {
        'a': 'qwsz',
        'b': 'vghn',
        'c': 'xdfv',
        'd': 'erfcxs',
        'e': 'rdsw',
        'f': 'rtgvcd',
        'g': 'tyhbvf',
        'h': 'yujnbg',
        'i': 'uojk',
        'j': 'uikmnh',
        'k': 'iojlm',
        'l': 'kop',
        'm': 'njk',
        'n': 'bhjm',
        'o': 'iklp',
        'p': 'ol',
        'q': 'wa',
        'r': 'etdf',
        's': 'awedcxz',
        't': 'ryfgh',
        'u': 'yihj',
        'v': 'cfgb',
        'w': 'qase',
        'x': 'zsdc',
        'y': 'tghu',
        'z': 'asx'
    }

    new_word = list(word)
    substitution_done = False
    while not substitution_done:
        i = random.randint(0, len(word)-1)
        char = word[i]
        if char in nearby_chars:
            new_char = random.choice(nearby_chars[char])
            if new_char != char:
                new_word[i] = new_char
                substitution_done = True
    return ''.join(new_word)


def omission_error(word):
    if len(word) > 1:
        index = random.randint(0, len(word) - 1)
        word = word[:index] + word[index + 1:]
    return word


def insertion_error(word):
    index = random.randint(0, len(word))
    char = random.choice('abcdefghijklmnopqrstuvwxyz')
    word = word[:index] + char + word[index:]
    return word


def reversal_error(word):
    if len(word) > 1:
        index1 = random.randint(0, len(word) - 2)
        index2 = index1 + 1
        char1 = word[index1]
        char2 = word[index2]
        word = word[:index1] + char2 + char1 + word[index2 + 1:]
    return word


def double_typing_error(word):
    if len(word) > 0:
        index = random.randint(0, len(word) - 1)
        word = word[:index] + word[index] + word[index:]
    return word


def spacing_error(sentence):
    index = random.randint(0, len(sentence))
    if random.choice([True, False]):
        sentence = sentence[:index] + ' ' + sentence[index:]
    else:
        if index < len(sentence) and sentence[index] == ' ':
            sentence = sentence[:index] + sentence[index + 1:]
    return sentence


def generate_random_error():
    error_functions = [substitution_error, omission_error, insertion_error, reversal_error,
                       double_typing_error, spacing_error]
    return random.choice(error_functions)


def generate_typos(sentence):
    generated_sentences = []
    num_words = len(sentence.split())
    average_typos = round(num_words / 10)

    while len(generated_sentences) < 10:
        typo_sentence = sentence
        num_typos = random.randint(max(1, average_typos - 2), min(average_typos + 2, num_words))
        for _ in range(num_typos):
            error_function = generate_random_error()
            typo_sentence = error_function(typo_sentence)
        if typo_sentence != sentence and typo_sentence not in generated_sentences:
            generated_sentences.append(typo_sentence)

    return generated_sentences


original_sentence = "can I go to the restaurant at this moment?"
typos = generate_typos(original_sentence)
print("Original sentence:", original_sentence)
print("Typos:")
for typo in typos:
    print("- " + typo)
