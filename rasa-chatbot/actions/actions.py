from datetime import datetime
from typing import Any, Text, Dict, List

from rasa_sdk import Action, Tracker
from rasa_sdk.executor import CollectingDispatcher
from rasa_sdk.events import SlotSet

import json


def load_json_file(file_path):
    with open(file_path, "r") as file:
        data = json.load(file)

    return data.get('items', [])


OPENING_HOURS = load_json_file("data/opening_hours.json")
MENU_ITEMS = load_json_file("data/menu.json")


def count_delimiters_in_message(message: str) -> int:
    commas_count = message.count(',')
    has_and = ' and ' in message

    if has_and:
        items_count = commas_count + 2
    else:
        items_count = commas_count + 1

    return items_count


class ActionCheckIsOpen(Action):
    def name(self) -> Text:
        return "action_check_is_open"

    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        entities = tracker.latest_message.get("entities")
        day_entity = next((entity for entity in entities if entity["entity"] == "day"), None)
        time_entity = next((entity for entity in entities if entity["entity"] == "time"), None)

        if day_entity and time_entity:
            day = day_entity["value"]
            time = int(time_entity["value"])

            if day in OPENING_HOURS:
                open_time, close_time = OPENING_HOURS[day]["open"], OPENING_HOURS[day]["close"]
                if open_time <= time < close_time:
                    dispatcher.utter_message(response="utter_is_open", day=day, time=time)
                else:
                    dispatcher.utter_message(text="No, the restaurant is closed at that time.")
            else:
                dispatcher.utter_message(text="Sorry, I don't have information for that day.")
        else:
            dispatcher.utter_message(text="Sorry, I didn't understand which day and time you're asking about.")

        return []


class ActionGetOpeningHours(Action):
    def name(self) -> Text:
        return "action_get_opening_hours"

    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        day = next(tracker.get_latest_entity_values("day"), None)

        if day:
            if day in OPENING_HOURS:
                open_time, close_time = OPENING_HOURS[day]["open"], OPENING_HOURS[day]["close"]
                dispatcher.utter_message(response="utter_opening_hours", day=day, open_time=open_time,
                                         close_time=close_time)
            else:
                dispatcher.utter_message(text="Sorry, I don't have information for that day.")
        else:
            dispatcher.utter_message(text="Sorry, I didn't understand which day you're asking about.")

        return []


class ActionCheckCurrentlyOpen(Action):
    def name(self) -> Text:
        return "action_check_currently_open"

    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        current_day, current_time = datetime.now().strftime("%A"), datetime.now().hour

        if current_day in OPENING_HOURS:
            open_time, close_time = OPENING_HOURS[current_day]["open"], OPENING_HOURS[current_day]["close"]
            if open_time <= current_time < close_time:
                dispatcher.utter_message(response="utter_currently_open")
            else:
                dispatcher.utter_message(response="utter_currently_closed")

        return []


class ActionListMenu(Action):
    def name(self) -> Text:
        return "action_list_menu"

    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        max_lengths = {"name": 0, "price": len("Price"), "preparation_time": len("Preparation_time")}

        for item in MENU_ITEMS:
            for key, value in item.items():
                if key == "price" or key == "preparation_time":
                    value = str(value)
                max_lengths[key] = max(max_lengths[key], len(value))
        max_name_length = max(max_lengths["name"], len("Name"))

        table = "```markdown\n"
        table += (f"| {'Name'.center(max_name_length)} | {'Price'.center(max(max_lengths['price'], len('Price'))) } | "
                  f"{'Preparation_time'.center(max_lengths['preparation_time'])} |\n")
        table += (f"|{'-' * (max_name_length + 2)}|{'-' * (max(max_lengths['price'], len('Price')) + 2)}|"
                  f"{'-' * (max_lengths['preparation_time'] + 2)}|\n")
        for item in MENU_ITEMS:
            name = item["name"].center(max_name_length)
            price = str(item["price"]).center(max_lengths["price"])
            prep_time = str(item["preparation_time"]).center(max_lengths["preparation_time"])
            table += f"| {name} | {price} | {prep_time} |\n"
        table += "```"

        dispatcher.utter_message(text=table)

        return []


class ActionSingleItemOrder(Action):
    def name(self) -> Text:
        return "action_place_single_item_order"

    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        requested_item = next(tracker.get_latest_entity_values("food"), None)

        if requested_item:
            if any(item['name'].lower() == requested_item.lower() for item in MENU_ITEMS):
                dispatcher.utter_message("{} has been added to the order.".format(requested_item))

                current_order = tracker.get_slot("current_order") or []
                current_order.append(requested_item)

                dispatcher.utter_message("Do you want to order anything else? If so, please let me know what you "
                                         "would like to order.")

                return [SlotSet("current_order", current_order)]

        dispatcher.utter_message("Sorry, we don't have that item in our menu.")
        dispatcher.utter_message("Do you want to order anything else? If so, please let me know what you "
                                 "would like to order.")

        return []


class ActionPlaceOrderWithMultipleItems(Action):
    def name(self) -> Text:
        return "action_place_order_with_multiple_items"

    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        user_message = tracker.latest_message.get('text', '')
        items_count = count_delimiters_in_message(user_message)

        food_entities = [entity['value'] for entity in tracker.latest_message.get('entities', [])
                         if entity['entity'] == 'food']
        menu_dish_names = [item['name'].lower() for item in MENU_ITEMS]
        available_items = [item for item in food_entities if item.lower() in menu_dish_names]

        current_order = tracker.get_slot("current_order") or []

        if len(available_items) > 0:
            if items_count > len(available_items):
                if len(available_items) == 1:
                    dispatcher.utter_message("{} has been added to the order.".format(", ".join(available_items)))
                    current_order.append(available_items[0])
                    if items_count - len(available_items) > 1:
                        dispatcher.utter_message("The remaining {} items couldn't be ordered."
                                                 .format(items_count - len(available_items)))
                    else:
                        dispatcher.utter_message("The remaining item couldn't be ordered.")
                    dispatcher.utter_message("Do you want to order anything else? If so, please let me know what you "
                                             "would like to order.")
                else:
                    dispatcher.utter_message("{} have been added to the order.".format(", ".join(available_items)))
                    current_order.extend(available_items)
                    if items_count - len(available_items) > 1:
                        dispatcher.utter_message("The remaining {} items couldn't be ordered."
                                                 .format(items_count - len(available_items)))
                    else:
                        dispatcher.utter_message("The remaining item couldn't be ordered.")
                    dispatcher.utter_message("Do you want to order anything else? If so, please let me know what you "
                                             "would like to order.")
            else:
                dispatcher.utter_message("{} have been added to the order.".format(", ".join(available_items)))
                current_order.extend(available_items)
                dispatcher.utter_message("Do you want to order anything else? If so, please let me know what you "
                                         "would like to order.")
        else:
            dispatcher.utter_message("Sorry, we don't have the items in our menu.")
            dispatcher.utter_message("Do you want to order anything else? If so, please let me know what you "
                                     "would like to order.")
            return []

        return [SlotSet("current_order", current_order)]


class ActionPlaceOrderWithAdditionalRequest(Action):
    def name(self) -> Text:
        return "action_place_order_with_additional_request"

    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        user_message = tracker.latest_message.get('text', '')
        items_count = count_delimiters_in_message(user_message)

        food_entities = [entity['value'] for entity in tracker.latest_message.get('entities', [])
                         if entity['entity'] == 'food']
        ingredients_entities = [entity['value'] for entity in tracker.latest_message.get('entities', [])
                                if entity['entity'] == 'ingredient']
        modifiers_entities = [entity['value'] for entity in tracker.latest_message.get('entities', [])
                              if entity['entity'] == 'modifier']
        menu_dish_names = [item['name'].lower() for item in MENU_ITEMS]
        allowed_ingredients = ["tomatoes", "meat", "mustard", "pickles", "ketchup", "onions", "cheese"]
        available_items = [item for item in food_entities if item.lower() in menu_dish_names]
        correct_additional_requests = [item for item in ingredients_entities if item.lower() in allowed_ingredients]

        current_order = tracker.get_slot("current_order") or []

        if len(food_entities) == items_count:
            if len(available_items) == items_count:
                if items_count == 1:
                    if correct_additional_requests:
                        order = ""
                        for food, modifier, ingredient in zip(food_entities, modifiers_entities, ingredients_entities):
                            order += f"{food} {modifier} {ingredient}"
                            current_order.append(order)
                        dispatcher.utter_message(order + " has been added to the order.")
                        dispatcher.utter_message("Do you want to order anything else? If so, please let me know what "
                                                 "you would like to order.")
                    else:
                        dispatcher.utter_message("Sorry, the additional request for your order cannot be fulfilled. "
                                                 "The order has not been placed.")
                        dispatcher.utter_message(
                            "Do you want to order anything else? If so, please let me know what you "
                            "would like to order.")
                        return []
                else:
                    if len(correct_additional_requests) == items_count:
                        complete_order = []
                        for food, modifier, ingredient in zip(food_entities, modifiers_entities, ingredients_entities):
                            order = f"{food} {modifier} {ingredient}"
                            complete_order.append(order)
                            current_order.append(order)
                        order = ", ".join(complete_order)
                        dispatcher.utter_message(order + " have been added to the order.")
                        dispatcher.utter_message("Do you want to order anything else? If so, please let me know what "
                                                 "you would like to order.")
                    else:
                        dispatcher.utter_message("Sorry, not all additional requests for your order can be fulfilled. "
                                                 "The order has not been placed.")
                        dispatcher.utter_message(
                            "Do you want to order anything else? If so, please let me know what you "
                            "would like to order.")
                        return []
            else:
                dispatcher.utter_message("Sorry, it seems that your order is too complex for me to process at the "
                                         "moment. Could you please simplify your order or provide it in separate "
                                         "messages?")
                return []
        else:
            dispatcher.utter_message("Sorry, it seems that your order is too complex for me to process at the moment. "
                                     "Could you please simplify your order or provide it in separate messages?")

            return []

        return [SlotSet("current_order", current_order)]


class ActionConfirmOrder(Action):
    def name(self) -> Text:
        return "action_confirm_order"

    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        current_order = tracker.get_slot("current_order")

        if current_order:
            dispatcher.utter_message("Your current order is: {}".format(", ".join(current_order)))
            dispatcher.utter_message("Is your order correct?")
        else:
            dispatcher.utter_message("Alright, it seems like you haven't ordered anything this time. "
                                     "We hope you find something for you next time. Goodbye and see you again!")

        return [SlotSet("current_order", None)]


class ActionResetOrder(Action):
    def name(self) -> Text:
        return "action_reset_order"

    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        dispatcher.utter_message("You didn't confirm your order so it got reset. Please order again.")
        return [SlotSet("current_order", None)]
