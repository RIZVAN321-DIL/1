class ReviewService:
    def __init__(self, session):
        self.session = session
    async def create_review(self, client_id: int, master_id: int, booking_id: int, rating: int, comment: str | None = None):
        pass
