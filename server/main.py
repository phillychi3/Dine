from openai import OpenAI
from openai import NOT_GIVEN
import googlemaps
from geopy.geocoders import Nominatim
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from enum import Enum
from dotenv import load_dotenv
import os
import json


load_dotenv()
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
google_maps_api_key = os.getenv("GOOGLE_MAPS_API_KEY")
gmaps = googlemaps.Client(key=google_maps_api_key)


app = FastAPI(
    title="Dine",
    description="something",
    version="1.0.0",
)

origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class temp_db:
    def __init__(self):
        self.db = "temp.json"

    def get(self, key) -> str | None:
        with open(self.db) as f:
            data = json.load(f)
            if key not in data:
                return None
            return data[key]

    def set(self, key, value) -> None:
        with open(self.db) as f:
            data = json.load(f)
            data[key] = value
            json.dump(data, f)

    def get_all(self) -> dict:
        with open(self.db) as f:
            data = json.load(f)
            return data

    def clean(self) -> None:
        with open(self.db) as f:
            data = json.load(f)
            data = {}
            json.dump(data, f)


def get_location(city: str):
    geolocator = Nominatim(user_agent="FineYourDineTonight")
    location = geolocator.geocode(city)
    return location.latitude, location.longitude


def get_coordinates(location):
    geocode_result = gmaps.geocode(location)
    if geocode_result:
        lat = geocode_result[0]["geometry"]["location"]["lat"]
        lng = geocode_result[0]["geometry"]["location"]["lng"]
        return lat, lng
    else:
        raise ValueError("无法获取该地址的经纬度")


# By jk
def search_restaurants(
    location: str | tuple[float, float], radius=5000, min_rating=3.0, open_now=True
):
    if isinstance(location, str):
        lat, lng = get_location(location)
    else:
        lat, lng = location
    places_result = gmaps.places_nearby(
        location=(lat, lng), radius=radius, type="restaurant", open_now=open_now
    )
    restaurants = []
    for place in places_result["results"]:
        try:
            name = place["name"]
            address = place.get("vicinity", "N/A")
            rating = place.get("rating", "N/A")
            total_ratings = place.get("user_ratings_total", 0)

            if rating != "N/A" and rating >= min_rating:  # 过滤评分低于min_rating的餐馆
                restaurants.append(
                    {
                        "Name": name,
                        "Address": address,
                        "Rating": rating,
                        "Total Ratings": total_ratings,
                        "Open Now": "Yes" if open_now else "N/A",
                    }
                )
        except KeyError:
            continue

    return restaurants

class ConversationState(Enum):
    INIT = "init"
    QUESTIONING = "questioning"
    FINAL = "final"


class Conversation(BaseModel):
    state: ConversationState
    questions: List[str] = []
    answers: List[str] = []
    recommendation: Optional[str] = None


conversations = {}


def get_gpt_response(prompt: str, message: str, isjson=False,tokens=150) -> str:
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": prompt},
            {"role": "user", "content": message},
        ],
        max_tokens=tokens,
        temperature=0.7,
        response_format={"type": "json_object"} if isjson else NOT_GIVEN,
    )
    return response.choices[0].message.content.strip()


@app.post("/start_conversation/")
async def start_conversation(user_id: str):
    if user_id in conversations:
        raise HTTPException(
            status_code=400, detail="Conversation already exists for this user"
        )

    initial_prompt = """You are a restaurant recommendation system. Engage in a step-by-step process to help the user decide what they might want to eat for dinner. Ask relevant questions about their mood, taste preferences, whether they want something light or heavy, if they are in a rush, etc. Ask one question at a time. Start with your first question.
    """
    initial_message = """Now you need to ask the user a question to help recommend a dinner option. What would you like to ask?
    """
    first_question = get_gpt_response(initial_prompt, initial_message)

    conversations[user_id] = Conversation(
        state=ConversationState.QUESTIONING, questions=[first_question]
    )

    return {"message": "Conversation started", "question": first_question}


@app.post("/answer_question/")
async def answer_question(user_id: str, answer: str):
    if user_id not in conversations:
        raise HTTPException(status_code=404, detail="Conversation not found")

    conversation = conversations[user_id]
    conversation.answers.append(answer)

    if len(conversation.answers) >= 3:
        conversation.state = ConversationState.FINAL
        prompt = (
            "Based on the following conversation, suggest a type of cuisine or specific food the user might enjoy for dinner:\n\n"
            + "".join(f"Q: {q}\nA: {a}\n" for q, a in zip(conversation.questions, conversation.answers))
        )
        message = """Based on the following conversation, suggest a type of cuisine or specific food the user might enjoy for dinner:
        give a list of user waht to eat, type of cuisine or specific food
        """

        recommendation = get_gpt_response(prompt, message)
        conversation.recommendation = recommendation
        return {"message": "Conversation completed", "recommendation": recommendation}

    else:
        prompt = (
            "Continue the conversation. Given the following exchange, ask the next relevant question to help recommend a dinner option, "
            "Don't ask the same question as the previous one, but ask about the psychology of mood:\n\n"
            + "".join(f"Q: {q}\nA: {a}\n" for q, a in zip(conversation.questions, conversation.answers))
        )
        message = """User has answered the question, continue the conversation. Given the following exchange, ask the next relevant question to help recommend a dinner option,
        """
        next_question = get_gpt_response(prompt, message)
        conversation.questions.append(next_question)
        return {"message": "Question answered", "next_question": next_question}


@app.get("/get_recommendation/")
async def get_recommendation(user_id: str):
    if user_id not in conversations:
        raise HTTPException(status_code=404, detail="Conversation not found")

    conversation = conversations[user_id]
    if conversation.state != ConversationState.FINAL:
        raise HTTPException(status_code=400, detail="Conversation is not yet complete")

    return {"recommendation": conversation.recommendation}


@app.get("/get_recommendation_restaurant/")
async def get_recommendation_restaurant(user_id: str, locate: str):
    if user_id not in conversations:
        raise HTTPException(status_code=404, detail="Conversation not found")

    conversation = conversations[user_id]
    if conversation.state != ConversationState.FINAL:
        raise HTTPException(status_code=400, detail="Conversation is not yet complete")

    recommendation = conversation.recommendation
    restaurants = search_restaurants(locate)

    prompt = f"""user want to eat: {recommendation}
    You Need only return json type Like: restaurants:[{{"name": "restaurant name", "address": "restaurant address","reason": "reason"}}]
    max 3 restaurants
    """
    message = (
        "restaurants near by the user:\n"
        + "".join(f"Name: {restaurant['Name']}\nAddress: {restaurant['Address']}\n" for restaurant in restaurants)
    )
    recommendation = get_gpt_response(prompt, message, isjson=True, tokens=300)
    print(recommendation)
    try:
        json_recommendation = json.loads(recommendation)
    except json.JSONDecodeError:
        json_recommendation = []

    if restaurants:
        return {
            "status": "success",
            "recommendation": json_recommendation,
            "origin_restaurant": recommendation,
            "restaurants": [
                {"name": restaurant["Name"], "address": restaurant["Address"]}
                for restaurant in restaurants
            ],
        }
    else:
        return {"status": "error", "message": "No nearby restaurants found."}


@app.get("/search_restaurants/")
async def find_restaurants(city: str):
    restaurants = search_restaurants(city)
    if restaurants:
        return {
            "status": "success",
            "restaurants": [
                {"name": restaurant["Name"], "address": restaurant["Address"]}
                for restaurant in restaurants
            ],
        }
    else:
        return {"status": "error", "message": "No nearby restaurants found."}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
