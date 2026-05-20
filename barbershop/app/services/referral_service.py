class ReferralService:
    def __init__(self, session):
        self.session = session
    async def process_referral(self, client_id: int, referral_code: str):
        pass
