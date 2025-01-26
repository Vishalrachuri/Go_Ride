from sqlalchemy import create_engine, Column, Integer, String, DateTime, Float, ForeignKey, Enum, Boolean, Index
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

    # Relationships
    rides_as_driver = relationship("Ride", back_populates="driver", foreign_keys="[Ride.driver_id]")
    rides_as_rider = relationship("Ride", back_populates="rider", foreign_keys="[Ride.rider_id]")

class Ride(Base):
    __tablename__ = "rides"
    __table_args__ = (
        Index('idx_driver_status', 'driver_id', 'status'),
        Index('idx_rider_status', 'rider_id', 'status'),
        Index('idx_scheduled_time', 'scheduled_time'),
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
    price_per_seat = Column(Float, nullable=True)
    status = Column(
        Enum(RideStatus, name='ride_status_enum'),
        default=RideStatus.SCHEDULED,
        nullable=False
    )
    
    notes = Column(String(255), nullable=True)
    route_polyline = Column(String(255), nullable=True)
    estimated_duration = Column(Integer, nullable=True)  # In minutes
    actual_start_time = Column(DateTime, nullable=True)
    actual_end_time = Column(DateTime, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    driver = relationship("User", back_populates="rides_as_driver", foreign_keys=[driver_id])
    rider = relationship("User", back_populates="rides_as_rider", foreign_keys=[rider_id])

def init_db():
    try:
        # Drop all tables with CASCADE
        Base.metadata.drop_all(bind=engine)
        print("All tables dropped successfully")
        
        # Create all tables
        Base.metadata.create_all(bind=engine)
        print("All tables created successfully")
        
    except Exception as e:
        print(f"Error resetting database: {e}")
        raise

if __name__ == "__main__":
    init_db()