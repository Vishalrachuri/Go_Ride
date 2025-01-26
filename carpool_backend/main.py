from fastapi import FastAPI, HTTPException, Depends, Header, Query
from fastapi.security import OAuth2PasswordBearer
from typing import Optional, List
from passlib.context import CryptContext
from datetime import datetime, timedelta
from pydantic import BaseModel, EmailStr, validator, Field, conint
from sqlalchemy.orm import Session
from database import (
    SessionLocal, User, Ride, RideStatus, 
    Rating, Message, engine, Base
)
from fastapi.middleware.cors import CORSMiddleware
from jose import jwt, JWTError
import logging
from sqlalchemy import or_, and_

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Constants
PWD_CONTEXT = CryptContext(schemes=["bcrypt"], deprecated="auto")
SECRET_KEY = "Vishal@2001"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 1440  # 24 hours

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Database dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Authentication functions
def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    try:
        encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
        return encoded_jwt
    except Exception as e:
        logger.error(f"Error creating token: {e}")
        raise

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email = payload.get("sub")
        if email is None:
            raise HTTPException(status_code=401, detail="Invalid authentication token")
        
        user = db.query(User).filter(User.email == email).first()
        if user is None:
            raise HTTPException(status_code=401, detail="User not found")
        
        return user
    except JWTError:
        raise HTTPException(status_code=401, detail="Could not validate credentials")

# Pydantic models
class UserBase(BaseModel):
    email: EmailStr

    @validator('email')
    def email_required(cls, v):
        if not v:
            raise ValueError('Email is required')
        return v.lower()

class UserCreate(UserBase):
    password: str
    confirm_password: Optional[str] = None
    name: Optional[str] = None
    phone_number: Optional[str] = None
    date_of_birth: Optional[str] = None
    user_type: Optional[str] = None
    google_id: Optional[str] = None
    profile_picture: Optional[str] = None

    @validator("password")
    def validate_password(cls, v):
        if len(v) < 6:
            raise ValueError("Password must be at least 6 characters long")
        return v

    @validator("confirm_password", always=True)
    def validate_confirm_password(cls, v, values):
        if "password" in values and v != values["password"]:
            raise ValueError("Passwords do not match")
        return v

    @validator("user_type")
    def validate_user_type(cls, v):
        if v and v.lower() not in ["driver", "rider"]:
            raise ValueError("User type must be 'driver' or 'rider'")
        return v.lower() if v else None



class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserProfileUpdate(BaseModel):
    name: Optional[str] = None
    phone_number: Optional[str] = None
    date_of_birth: Optional[str] = None
    user_type: Optional[str] = None
    profile_picture: Optional[str] = None

class RideCreate(BaseModel):
    pickup_location: str
    pickup_latitude: float
    pickup_longitude: float
    destination: str
    destination_latitude: float
    destination_longitude: float
    scheduled_time: datetime
    seats_available: int = 1
    notes: Optional[str] = None
    route_polyline: Optional[str] = None
    estimated_duration: Optional[int] = None

class RideUpdate(BaseModel):
    status: str
    notes: Optional[str] = None
    actual_start_time: Optional[datetime] = None
    actual_end_time: Optional[datetime] = None

class RatingCreate(BaseModel):
    ride_id: int
    rated_user_id: int
    rating: conint(ge=1, le=5)
    comment: Optional[str] = None

class MessageCreate(BaseModel):
    ride_id: int
    receiver_id: int
    content: str

# User Routes
@app.post("/signup")
async def signup(user: UserCreate, db: Session = Depends(get_db)):
    try:
        # Check if email already exists
        existing_user = db.query(User).filter(User.email == user.email).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Email already registered")

        # Hash the password
        hashed_pw = PWD_CONTEXT.hash(user.password)

        # Create the user
        new_user = User(
            email=user.email,
            hashed_password=hashed_pw,
            name=user.name,
            phone_number=user.phone_number,
            date_of_birth=user.date_of_birth,
            user_type=user.user_type,
            google_id=user.google_id,
            profile_picture=user.profile_picture,
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)

        # Generate a JWT token
        token = create_access_token({"sub": new_user.email})

        return {
            "message": "User created successfully",
            "access_token": token,
            "token_type": "bearer",
        }
    except Exception as e:
        db.rollback()
        logger.error(f"Signup error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/login")
async def login(user: UserLogin, db: Session = Depends(get_db)):
    logger.info(f"Login attempt for email: {user.email}")
    try:
        # Find user - case insensitive
        db_user = db.query(User).filter(User.email.ilike(user.email.lower())).first()
        
        if db_user is None:
            logger.error(f"User not found: {user.email}")
            raise HTTPException(
                status_code=401,
                detail="Invalid credentials"
            )

        # Verify password
        if not PWD_CONTEXT.verify(user.password, db_user.hashed_password):
            logger.error("Invalid password")
            raise HTTPException(
                status_code=401,
                detail="Invalid credentials"
            )

        # Generate token
        access_token = create_access_token(data={"sub": db_user.email})
        
        # Create response
        response_data = {
            "message": "Login successful",
            "access_token": access_token,
            "token_type": "bearer",
            "user": {
                "id": db_user.id,
                "email": db_user.email,
                "name": db_user.name,
                "user_type": db_user.user_type,
                "phone_number": db_user.phone_number,
                "date_of_birth": db_user.date_of_birth,
                "profile_picture": db_user.profile_picture,
                "is_verified": db_user.is_verified,
                "is_active": db_user.is_active
            }
        }
        
        logger.info(f"Login successful for user: {user.email}")
        return response_data

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Ride Routes
@app.post("/rides")
async def create_ride(
    ride: RideCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        logger.info(f"Creating ride - User: {current_user.email}")

        new_ride = Ride(
            driver_id=current_user.id if current_user.user_type == "driver" else None,
            rider_id=current_user.id if current_user.user_type == "rider" else None,
            pickup_location=ride.pickup_location,
            pickup_latitude=ride.pickup_latitude,
            pickup_longitude=ride.pickup_longitude,
            destination=ride.destination,
            destination_latitude=ride.destination_latitude,
            destination_longitude=ride.destination_longitude,
            scheduled_time=ride.scheduled_time,
            seats_available=ride.seats_available,
            notes=ride.notes,
            route_polyline=ride.route_polyline,
            estimated_duration=ride.estimated_duration,
            status=RideStatus.SCHEDULED
        )

        db.add(new_ride)
        db.commit()
        db.refresh(new_ride)
        
        return {"message": "Ride created successfully", "ride": new_ride.to_dict()}
    except Exception as e:
        db.rollback()
        logger.error(f"Error creating ride: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/rides")
async def get_rides(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        rides = db.query(Ride).filter(
            or_(Ride.driver_id == current_user.id, Ride.rider_id == current_user.id)
        ).all()
        return {"rides": [ride.to_dict() for ride in rides]}
    except Exception as e:
        logger.error(f"Error fetching rides: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Rating Routes
@app.post("/ratings")
async def create_rating(
    rating: RatingCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        ride = db.query(Ride).filter(Ride.id == rating.ride_id).first()
        if not ride:
            raise HTTPException(status_code=404, detail="Ride not found")

        if ride.status != RideStatus.COMPLETED:
            raise HTTPException(status_code=400, detail="Can only rate completed rides")

        if current_user.id not in [ride.driver_id, ride.rider_id]:
            raise HTTPException(status_code=403, detail="Not authorized to rate this ride")

        new_rating = Rating(
            ride_id=rating.ride_id,
            rater_id=current_user.id,
            rated_user_id=rating.rated_user_id,
            rating=rating.rating,
            comment=rating.comment
        )

        db.add(new_rating)
        db.commit()
        db.refresh(new_rating)

        return {"message": "Rating submitted successfully"}
    except Exception as e:
        db.rollback()
        logger.error(f"Error creating rating: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Message Routes
@app.post("/messages")
async def send_message(
    message: MessageCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        ride = db.query(Ride).filter(Ride.id == message.ride_id).first()
        if not ride:
            raise HTTPException(status_code=404, detail="Ride not found")

        if current_user.id not in [ride.driver_id, ride.rider_id]:
            raise HTTPException(status_code=403, detail="Not authorized to send messages for this ride")

        new_message = Message(
            ride_id=message.ride_id,
            sender_id=current_user.id,
            receiver_id=message.receiver_id,
            content=message.content
        )

        db.add(new_message)
        db.commit()
        db.refresh(new_message)

        return {"message": "Message sent successfully"}
    except Exception as e:
        db.rollback()
        logger.error(f"Error sending message: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# User Profile Routes
@app.put("/user/profile")
async def update_user_profile(
    profile: UserProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        for field, value in profile.dict(exclude_unset=True).items():
            setattr(current_user, field, value)
        
        current_user.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(current_user)
        
        return {
            "message": "Profile updated successfully",
            "user": current_user.to_dict()
        }
    except Exception as e:
        db.rollback()
        logger.error(f"Error updating profile: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Initialize database tables
def init_db():
    Base.metadata.create_all(bind=engine)

if __name__ == "__main__":
    import uvicorn
    init_db()
    uvicorn.run(app, host="0.0.0.0", port=8000)