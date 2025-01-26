# database.py
from sqlalchemy import (
    create_engine, Column, Integer, String, DateTime, Float, ForeignKey, 
    Enum as SQLAlchemyEnum, CheckConstraint, Index, Boolean, Text
)
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime
import enum

DATABASE_URL = "postgresql://postgres:Vishal%402001@localhost:5432/CarpoolingApp"

engine = create_engine(DATABASE_URL, echo=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class RideStatus(enum.Enum):
    SCHEDULED = "scheduled"
    ACTIVE = "active"
    COMPLETED = "completed"
    CANCELLED = "cancelled"

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    name = Column(String(255), nullable=True)
    phone_number = Column(String(20), nullable=True)
    date_of_birth = Column(String(10), nullable=True)
    user_type = Column(String(10), nullable=True)
    google_id = Column(String(255), unique=True, nullable=True)
    profile_picture = Column(String(255), nullable=True)
    is_verified = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        CheckConstraint(
            "user_type IN ('driver', 'rider')", 
            name='valid_user_type'
        ),
    )

    # Relationships
    rides_as_driver = relationship(
        "Ride",
        back_populates="driver",
        foreign_keys="[Ride.driver_id]",
        cascade="all, delete-orphan"
    )
    rides_as_rider = relationship(
        "Ride",
        back_populates="rider",
        foreign_keys="[Ride.rider_id]",
        cascade="all, delete-orphan"
    )
    ratings_given = relationship(
        "Rating",
        back_populates="rater",
        foreign_keys="[Rating.rater_id]",
        cascade="all, delete-orphan"
    )
    ratings_received = relationship(
        "Rating",
        back_populates="rated_user",
        foreign_keys="[Rating.rated_user_id]",
        cascade="all, delete-orphan"
    )
    messages_sent = relationship(
        "Message",
        back_populates="sender",
        foreign_keys="[Message.sender_id]",
        cascade="all, delete-orphan"
    )
    messages_received = relationship(
        "Message",
        back_populates="receiver",
        foreign_keys="[Message.receiver_id]",
        cascade="all, delete-orphan"
    )

    def to_dict(self):
            return {
                "id": self.id,
                "email": self.email,
                "name": self.name,
                "phone_number": self.phone_number,
                "date_of_birth": self.date_of_birth,
                "user_type": self.user_type,
                "profile_picture": self.profile_picture,
                "is_verified": self.is_verified,
                "is_active": self.is_active,
                "created_at": self.created_at.isoformat() if self.created_at else None,
                "updated_at": self.updated_at.isoformat() if self.updated_at else None
            }
class Ride(Base):
    __tablename__ = "rides"
    __table_args__ = (
        Index('idx_driver_status', 'driver_id', 'status'),
        Index('idx_rider_status', 'rider_id', 'status'),
        Index('idx_scheduled_time', 'scheduled_time'),
        Index('idx_status', 'status')
    )

    id = Column(Integer, primary_key=True, index=True)
    driver_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    rider_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    
    pickup_location = Column(String(255), nullable=False)
    pickup_latitude = Column(Float, nullable=False)
    pickup_longitude = Column(Float, nullable=False)
    
    destination = Column(String(255), nullable=False)
    destination_latitude = Column(Float, nullable=False)
    destination_longitude = Column(Float, nullable=False)
    
    scheduled_time = Column(DateTime, nullable=False)
    seats_available = Column(Integer, default=1)
    status = Column(
        SQLAlchemyEnum(RideStatus, name='ride_status_enum'),
        default=RideStatus.SCHEDULED,
        nullable=False
    )
    
    notes = Column(Text, nullable=True)
    route_polyline = Column(Text, nullable=True)
    estimated_duration = Column(Integer, nullable=True)  # In minutes
    actual_start_time = Column(DateTime, nullable=True)
    actual_end_time = Column(DateTime, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    driver = relationship("User", back_populates="rides_as_driver", foreign_keys=[driver_id])
    rider = relationship("User", back_populates="rides_as_rider", foreign_keys=[rider_id])
    ratings = relationship("Rating", back_populates="ride", cascade="all, delete-orphan")
    messages = relationship("Message", back_populates="ride", cascade="all, delete-orphan")

    def to_dict(self):
        return {
            "id": self.id,
            "driver_id": self.driver_id,
            "rider_id": self.rider_id,
            "pickup_location": self.pickup_location,
            "pickup_latitude": self.pickup_latitude,
            "pickup_longitude": self.pickup_longitude,
            "destination": self.destination,
            "destination_latitude": self.destination_latitude,
            "destination_longitude": self.destination_longitude,
            "scheduled_time": self.scheduled_time.isoformat() if self.scheduled_time else None,
            "seats_available": self.seats_available,
            "status": self.status.value,
            "notes": self.notes,
            "estimated_duration": self.estimated_duration,
            "actual_start_time": self.actual_start_time.isoformat() if self.actual_start_time else None,
            "actual_end_time": self.actual_end_time.isoformat() if self.actual_end_time else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "driver": self.driver.to_dict() if self.driver else None,
            "rider": self.rider.to_dict() if self.rider else None
        }

class Rating(Base):
    __tablename__ = "ratings"
    
    id = Column(Integer, primary_key=True, index=True)
    ride_id = Column(Integer, ForeignKey("rides.id", ondelete="CASCADE"), nullable=False)
    rater_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    rated_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    rating = Column(Integer, CheckConstraint("rating >= 1 AND rating <= 5"), nullable=False)
    comment = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    ride = relationship("Ride", back_populates="ratings")
    rater = relationship("User", foreign_keys=[rater_id], back_populates="ratings_given")
    rated_user = relationship("User", foreign_keys=[rated_user_id], back_populates="ratings_received")

class Message(Base):
    __tablename__ = "messages"
    
    id = Column(Integer, primary_key=True, index=True)
    ride_id = Column(Integer, ForeignKey("rides.id", ondelete="CASCADE"), nullable=False)
    sender_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    receiver_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    content = Column(Text, nullable=False)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    ride = relationship("Ride", back_populates="messages")
    sender = relationship("User", foreign_keys=[sender_id], back_populates="messages_sent")
    receiver = relationship("User", foreign_keys=[receiver_id], back_populates="messages_received")

def init_db():
    try:
        Base.metadata.drop_all(bind=engine)
        print("All tables dropped successfully")
        Base.metadata.create_all(bind=engine)
        print("All tables created successfully")
    except Exception as e:
        print(f"Error initializing database: {e}")
        raise

if __name__ == "__main__":
    init_db()