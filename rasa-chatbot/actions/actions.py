from typing import Any, Text, Dict, List
from datetime import datetime

from rasa_sdk import Action, Tracker
from rasa_sdk.executor import CollectingDispatcher

OPENING_HOURS = {
    "Monday": {"open": 8, "close": 20},
    "Tuesday": {"open": 8, "close": 20},
    "Wednesday": {"open": 10, "close": 16},
    "Thursday": {"open": 8, "close": 20},
    "Friday": {"open": 8, "close": 20},
    "Saturday": {"open": 10, "close": 16},
    "Sunday": {"open": 0, "close": 0}
}

MENU_ITEMS = [
    {"dish_name": "Lasagne", "cost": "$16", "preparation_time": "1 h"},
    {"dish_name": "Pizza", "cost": "$12", "preparation_time": "30 min"},
    {"dish_name": "Hot-dog", "cost": "$4", "preparation_time": "6 min"},
    {"dish_name": "Burger", "cost": "$12.5", "preparation_time": "12 min"},
    {"dish_name": "Spaghetti Carbonara", "cost": "$15", "preparation_time": "30 min"},
    {"dish_name": "Tiramisu", "cost": "$11", "preparation_time": "9 min"}
]


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
        entities = tracker.latest_message.get("entities")
        day_entity = next((entity for entity in entities if entity["entity"] == "day"), None)

        if day_entity:
            day = day_entity["value"]

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
        max_lengths = {"dish_name": 0, "cost": 0, "preparation_time": len("Preparation_time")}
        for item in MENU_ITEMS:
            for key, value in item.items():
                max_lengths[key] = max(max_lengths[key], len(str(value)))
        max_dish_name_length = max(max_lengths["dish_name"], len("Dish_name"))

        table = "```markdown\n"
        table += (f"| {'Dish_name'.center(max_dish_name_length)} | {'Cost'.center(max_lengths['cost'])} | "
                  f"{'Preparation_time'.center(max_lengths['preparation_time'])} |\n")
        table += (f"|{'-' * (max_dish_name_length + 2)}|{'-' * (max_lengths['cost'] + 2)}|"
                  f"{'-' * (max_lengths['preparation_time'] + 2)}|\n")
        for item in MENU_ITEMS:
            dish_name = item["dish_name"].center(max_dish_name_length)
            cost = item["cost"].center(max_lengths["cost"])
            prep_time = item["preparation_time"].center(max_lengths["preparation_time"])
            table += f"| {dish_name} | {cost} | {prep_time} |\n"
        table += "```"

        dispatcher.utter_message(text=table)

        return []


class ActionSingleItemOrder(Action):
    def name(self) -> Text:
        return "action_place_single_item_order"

    def run(self, dispatcher: CollectingDispatcher,
            tracker: Tracker,
            domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:

        requested_items = tracker.get_latest_entity_values("food")

        if requested_items:
            for requested_item in requested_items:
                if any(item['dish_name'].lower() == requested_item.lower() for item in MENU_ITEMS):
                    dispatcher.utter_message("Your order has been placed. Thank you!")
                    return []

        dispatcher.utter_message("Sorry, we don't have that item in our menu.")
        return []


class ActionPlaceOrderWithMultipleItems(Action):
    def name(self) -> Text:
        return "action_place_order_with_multiple_items"

    def run(self, dispatcher: CollectingDispatcher,
            tracker: Tracker,
            domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:

        user_message = tracker.latest_message.get('text', '')
        items_count = count_delimiters_in_message(user_message)

        food_entities = [entity['value'] for entity in tracker.latest_message.get('entities', [])
                         if entity['entity'] == 'food']
        menu_dish_names = [item['dish_name'].lower() for item in MENU_ITEMS]
        unavailable_items = [item for item in food_entities if item.lower() not in menu_dish_names]
        available_items = [item for item in food_entities if item.lower() in menu_dish_names]
        if len(food_entities) == items_count:
            if len(available_items) == items_count:
                dispatcher.utter_message("Your order with multiple items has been placed. Thank you!")
            elif len(unavailable_items) < items_count:
                dispatcher.utter_message("Your order has been placed for {}. Thank you!"
                                         .format(", ".join(available_items)))
                if len(unavailable_items) > 1:
                    dispatcher.utter_message("The remaining {} items couldn't be ordered.".
                                             format(len(unavailable_items)))
                else:
                    dispatcher.utter_message("The remaining item couldn't be ordered.")
            else:
                dispatcher.utter_message("Sorry, we don't have the items in our menu.")
        elif len(available_items) > 0:
            if items_count > len(available_items):
                dispatcher.utter_message("Your order has been placed for {}. Thank you!"
                                         .format(", ".join(available_items)))
                if items_count - len(available_items) > 1:
                    dispatcher.utter_message("The remaining {} items couldn't be ordered."
                                             .format(items_count - len(available_items)))
                else:
                    dispatcher.utter_message("The remaining item couldn't be ordered.")
            else:
                dispatcher.utter_message("Your order with multiple items has been placed. Thank you!")
        else:
            dispatcher.utter_message("Sorry, we don't have the items in our menu.")

        return []


class ActionPlaceOrderWithAdditionalRequest(Action):
    def name(self) -> Text:
        return "action_place_order_with_additional_request"

    def run(self, dispatcher: CollectingDispatcher,
            tracker: Tracker,
            domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:

        user_message = tracker.latest_message.get('text', '')
        items_count = count_delimiters_in_message(user_message)

        food_entities = [entity['value'] for entity in tracker.latest_message.get('entities', [])
                         if entity['entity'] == 'food']
        ingredients_entities = [entity['value'] for entity in tracker.latest_message.get('entities', [])
                                if entity['entity'] == 'ingredient']
        menu_dish_names = [item['dish_name'].lower() for item in MENU_ITEMS]
        allowed_ingredients = ["tomatoes", "meat", "mustard", "pickles", "ketchup", "onions", "cheese"]
        available_items = [item for item in food_entities if item.lower() in menu_dish_names]
        correct_additional_requests = [item for item in ingredients_entities if item.lower() in allowed_ingredients]
        if len(food_entities) == items_count:
            if len(available_items) == items_count:
                if items_count == 1:
                    if correct_additional_requests:
                        dispatcher.utter_message("Your order with additional request has been placed. Thank you!")
                    else:
                        dispatcher.utter_message("Sorry, the additional request for your order cannot be fulfilled. "
                                                 "The order has not been placed.")
                else:
                    if len(correct_additional_requests) == items_count:
                        dispatcher.utter_message("Your order with multiple items and additional requests has been "
                                                 "placed. Thank you!")
                    else:
                        dispatcher.utter_message("Sorry, not all additional requests for your order can be fulfilled. "
                                                 "The order has not been placed.")
            else:
                dispatcher.utter_message("Sorry, it seems that your order is too complex for me to process at the "
                                         "moment. Could you please simplify your order or provide it in separate "
                                         "messages?")
        else:
            dispatcher.utter_message("Sorry, it seems that your order is too complex for me to process at the moment. "
                                     "Could you please simplify your order or provide it in separate messages?")

        return []
