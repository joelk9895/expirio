from fastapi import FastAPI, UploadFile, File
import uvicorn
from pathlib import Path
import logging
import google.generativeai as genai
import base64
import firebase_admin
from firebase_admin import credentials, firestore
import json

# Firebase setup
cred = credentials.Certificate("/Users/joelkgeorge/Developer/expiro/backend/expiro-78f13-firebase-adminsdk-mbmzy-113a7c0ef3.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# Logging setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# Configure Gemini
genai.configure(api_key="")
model = genai.GenerativeModel("gemini-1.5-pro")

# Create images directory
IMAGES_DIR = Path(__file__).parent / "images"
IMAGES_DIR.mkdir(exist_ok=True)
logger.info(f"Images directory: {IMAGES_DIR}")

@app.post("/upload-image/")
async def upload_image(file: UploadFile = File(...), prompt: str = "Identify all products visible in the image and provide their names along with their tentative expiry days. Respond strictly in JSON format with no additional text or explanation. Use the format: [{ 'name': 'product_name', 'expiryDays': number_of_days }, ...]. Ensure all names are descriptive, and expiryDays is an integer. No back tick with json specification"):
    try:
        if file is None:
            logger.error("No file received.")
            return {"error": "No file received."}

        # Log file details
        logger.info(f"Received file: {file.filename}")
        logger.info(f"Content type: {file.content_type}")

        # Read file contents
        contents = await file.read()
        logger.info(f"File size: {len(contents)} bytes")

        # Save the file locally
        file_path = IMAGES_DIR / file.filename
        logger.info(f"Saving to: {file_path}")
        with open(file_path, "wb") as f:
            f.write(contents)
        logger.info("File saved successfully")

        # Encode image for Gemini
        encoded_image = base64.b64encode(contents).decode('utf-8')

        # Generate content with Gemini
        try:
            response = model.generate_content([
                {
                    'mime_type': file.content_type,
                    'data': encoded_image
                },
                prompt
            ])
            gemini_analysis = response.text.replace("```", "")
            gemini_analysis = gemini_analysis.replace("json", "")

            response_json = json.loads(gemini_analysis)
            logger.info("Gemini analysis completed and parsed.")

            # # Save to Firebase Firestore
            for item in response_json:
                print(item)
                db.collection("products").add(item)
            logger.info("Analysis data saved to Firebase Firestore.")

        except Exception as gemini_error:
            logger.error(f"Gemini analysis error: {str(gemini_error)}")
            gemini_analysis = f"Error in analysis: {str(gemini_error)}"

        return {
            "filename": file.filename,
            "content_type": file.content_type,
            "size": len(contents),
            "file_path": str(file_path),
            "analysis": gemini_analysis
        }

    except Exception as e:
        logger.error(f"Error occurred: {str(e)}", exc_info=True)
        return {"error": str(e)}
    
@app.get("/products/")
async def get_products():
    try:
        products_ref = db.collection("products")
        docs = products_ref.stream()
        products = [doc.to_dict() for doc in docs]
        return {"products": products}
    except Exception as e:
        logger.error(f"Error fetching products: {str(e)}")
        return {"error": str(e)}
@app.post("/create-recipe/")
async def create_recipe(request: dict):
    try:
        # Extract ingredients from request
        ingredients = request.get('ingredients', [])
        
        if not ingredients:
            logger.error("No ingredients provided")
            return {"error": "No ingredients provided"}
            
        # Create prompt for Gemini
        prompt = f"""Create a recipe using some or all of these ingredients: {', '.join(ingredients)}. 
        Consider these are ingredients that need to be used soon to prevent waste.
        Format the response as a JSON object with the following structure:
        {{
            "recipe": "Recipe name",
            "ingredients": ["list of required ingredients with quantities"],
            "instructions": ["step by step cooking instructions"],
            "cookingTime": "estimated cooking time",
            "difficulty": "easy/medium/hard"
        }}
        Respond with only the JSON object, no additional text."""

        # Generate recipe with Gemini
        try:
            response = model.generate_content(prompt)
            recipe_text = response.text.replace("```json", "").replace("```", "")
            recipe_json = json.loads(recipe_text)
            
            logger.info("Recipe generated successfully")
            return recipe_json
            
        except Exception as gemini_error:
            logger.error(f"Gemini recipe generation error: {str(gemini_error)}")
            return {"error": f"Failed to generate recipe: {str(gemini_error)}"}
            
    except Exception as e:
        logger.error(f"Error in create_recipe endpoint: {str(e)}")
        return {"error": str(e)}
    
if __name__ == "__main__":
    logger.info("Starting server...")
    uvicorn.run(app, host="0.0.0.0", port=8000)

