import uuid, os
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from app.core.security import is_admin
from app.config import settings

router = APIRouter(prefix="/api", tags=["upload"])

@router.post("/admin/upload-photo")
async def upload_photo(admin_telegram_id: int = Form(...), photo: UploadFile = File(...)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    if not photo.content_type or not photo.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Только изображения")
    ext = os.path.splitext(photo.filename or "photo.jpg")[1] or ".jpg"
    filename = f"{uuid.uuid4().hex}{ext}"
    upload_dir = settings.UPLOAD_DIR
    os.makedirs(upload_dir, exist_ok=True)
    filepath = os.path.join(upload_dir, filename)
    content = await photo.read()
    with open(filepath, "wb") as f:
        f.write(content)
    return {"ok": True, "path": f"/static/uploads/{filename}"}
