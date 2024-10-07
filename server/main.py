import openai
import googlemaps
from geopy.geocoders import Nominatim
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from enum import Enum


openai.api_key = "OpenAI API"
google_maps_api_key = "Google Maps API"
gmaps = googlemaps.Client(key=google_maps_api_key)


app = FastAPI(
    title="Dine",
    description="something",
    version="1.0.0",
)


def get_location(city: str):
    geolocator = Nominatim(user_agent="geoapiExercises")
    location = geolocator.geocode(city)
    return location.latitude, location.longitude


def find_nearby_restaurants(lat: float, lng: float, keyword: str = "restaurant"):
    location = (lat, lng)
    places_result = gmaps.places_nearby(
        location, radius=1500, type="restaurant", keyword=keyword
    )
    return places_result["results"]


app = FastAPI(
    title="Dine",
    description="Interactive restaurant recommendation system",
    version="1.0.0",
)


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


def get_gpt_response(prompt: str) -> str:
    response = openai.Completion.create(
        engine="gpt-4-turbo", prompt=prompt, max_tokens=150, temperature=0.7
    )
    return response["choices"][0]["text"].strip()


@app.post("/start_conversation/")
async def start_conversation(user_id: str):
    if user_id in conversations:
        raise HTTPException(
            status_code=400, detail="Conversation already exists for this user"
        )

    initial_prompt = """
    You are a restaurant recommendation system. Engage in a step-by-step process to help the user decide what they might want to eat for dinner. Ask relevant questions about their mood, taste preferences, whether they want something light or heavy, if they are in a rush, etc. Ask one question at a time. Start with your first question.
    """
    first_question = get_gpt_response(initial_prompt)

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

    if len(conversation.answers) >= 5:
        conversation.state = ConversationState.FINAL
        prompt = f"""
        Based on the following conversation, suggest a type of cuisine or specific food the user might enjoy for dinner:

        {"".join(f"Q: {q}\nA: {a}\n" for q, a in zip(conversation.questions, conversation.answers))}
        """
        recommendation = get_gpt_response(prompt)
        conversation.recommendation = recommendation
        return {"message": "Conversation completed", "recommendation": recommendation}

    else:
        prompt = f"""
        Continue the conversation. Given the following exchange, ask the next relevant question to help recommend a dinner option:

        {"".join(f"Q: {q}\nA: {a}\n" for q, a in zip(conversation.questions, conversation.answers))}
        """
        next_question = get_gpt_response(prompt)
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


@app.get("/find_restaurants/")
async def find_restaurants(user_id: str, city: str):
    if (
        user_id not in conversations
        or conversations[user_id].state != ConversationState.FINAL
    ):
        raise HTTPException(
            status_code=400, detail="Please complete the conversation first"
        )

    recommendation = conversations[user_id].recommendation
    lat, lng = get_location(city)
    restaurants = find_nearby_restaurants(lat, lng, recommendation)

    if restaurants:
        return {
            "status": "success",
            "recommendation": recommendation,
            "restaurants": [
                {"name": restaurant["name"], "address": restaurant["vicinity"]}
                for restaurant in restaurants[:5]
            ],
        }
    else:
        return {"status": "error", "message": "No nearby restaurants found."}
