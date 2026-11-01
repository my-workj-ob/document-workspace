package i18n

import (
	"context"
	"fmt"
	"net/http"
	"strings"
)

type contextKey string

const LocaleKey contextKey = "locale"

// Supported locales
const (
	LocaleUZ = "uz"
	LocaleEN = "en"
	LocaleRU = "ru"
)

// ParseLocale resolves the best-matching locale from the Accept-Language header or query.
func ParseLocale(header string) string {
	raw := strings.ToLower(strings.TrimSpace(header))
	if raw == "" {
		return LocaleEN
	}

	// Examples: "en-US,en;q=0.9,ru;q=0.8,uz;q=0.7", "en", "uz-UZ", "ru"
	parts := strings.Split(raw, ",")
	for _, part := range parts {
		sub := strings.TrimSpace(strings.Split(part, ";")[0])
		if strings.HasPrefix(sub, "en") {
			return LocaleEN
		}
		if strings.HasPrefix(sub, "ru") {
			return LocaleRU
		}
		if strings.HasPrefix(sub, "uz") {
			return LocaleUZ
		}
	}

	return LocaleEN
}

// GetLocale extracts the resolved locale from context, or defaults to "en".
func GetLocale(ctx context.Context) string {
	if ctx == nil {
		return LocaleEN
	}
	if loc, ok := ctx.Value(LocaleKey).(string); ok && loc != "" {
		return loc
	}
	return LocaleEN
}

// GetLocaleFromRequest extracts the locale from the request context or Accept-Language header.
func GetLocaleFromRequest(r *http.Request) string {
	if r == nil {
		return LocaleEN
	}
	if loc, ok := r.Context().Value(LocaleKey).(string); ok && loc != "" {
		return loc
	}
	return ParseLocale(r.Header.Get("Accept-Language"))
}

// WithLocale returns a child context carrying the specified locale.
func WithLocale(ctx context.Context, locale string) context.Context {
	clean := strings.ToLower(strings.TrimSpace(locale))
	if clean != LocaleUZ && clean != LocaleEN && clean != LocaleRU {
		clean = LocaleUZ
	}
	return context.WithValue(ctx, LocaleKey, clean)
}

// T returns the translated string for the given locale and key.
func T(locale string, key string, args ...any) string {
	loc := strings.ToLower(strings.TrimSpace(locale))
	if loc != LocaleUZ && loc != LocaleEN && loc != LocaleRU {
		loc = LocaleUZ
	}

	langMap, ok := dictionary[key]
	if !ok {
		return key
	}

	msg, ok := langMap[loc]
	if !ok {
		msg, ok = langMap[LocaleUZ]
		if !ok {
			return key
		}
	}

	if len(args) > 0 {
		return fmt.Sprintf(msg, args...)
	}
	return msg
}

// System Prompt for AI tailored to the user's selected language
func GetAISystemPrompt(locale string) string {
	switch strings.ToLower(locale) {
	case LocaleRU:
		return "Вы — Cognidoc AI, высокоинтеллектуальный ассистент по анализу документов, PDF и исследований. Отвечайте пользователю на безупречном, грамотном и профессиональном русском языке. Предоставляйте четкие, структурированные и точные ответы, опираясь исключительно на факты из документов. Вы не предоставляете юридических консультаций. Математические формулы, матрицы и системы уравнений оформляйте четко в стандартном формате LaTeX с блоками $$ ... $$ и переносами строк матриц через двойной обратный слеш."
	case LocaleUZ:
		return "Siz Cognidoc AI — hujjatlar, PDF va tadqiqotlar tahlili bo'yicha professional sun'iy intellekt yordamchisisiz. Har doim foydalanuvchiga savodli, aniq va professional o'zbek tilida javob bering. Hujjatlar mazmunini tushunarli, tizimli va ishonchli faktlar bilan yoritib bering. Rasmiy yuridik yoki qonuniy maslahatlar bermang. Matematik formulalar, matritsalar va tenglamalar tizimlarini chiroyli va standart LaTeX formatida ($$ ... $$) yozing, matritsa qatorlarini ikkita teskari slesh bilan ajrating."
	default:
		return "You are Cognidoc AI, an advanced artificial intelligence assistant for documents, PDF files, research, and technical analysis. Always answer the user in articulate, professional, and grammatically precise English with clear structure and analytical depth. Base your answers strictly on facts from uploaded documents or verified knowledge. Do not provide formal legal advice or legal counsel. Format mathematical formulas, matrices, and systems of equations cleanly using standard LaTeX blocks $$ ... $$ with double backslashes for row breaks."
	}
}

// RAG Document Context instruction localized
func GetRAGInstruction(locale string, docContext string) string {
	switch strings.ToLower(locale) {
	case LocaleRU:
		return fmt.Sprintf("[Контекст документов:\n%s\n\nИНСТРУКЦИЯ: Отвечайте строго на основе фактов из приведенных выше фрагментов документов. Указывайте точные номера страниц цитат (например, [Страница N]). Если в документах нет ответа на вопрос, честно сообщите об этом, не выдумывая.]", docContext)
	case LocaleEN:
		return fmt.Sprintf("[Document Context:\n%s\n\nINSTRUCTION: Base your answer strictly on the facts provided in the document extracts above. Always include exact page citations (e.g. [Page N]). If the requested information is not present in the document, explicitly state so without fabricating.]", docContext)
	default:
		return fmt.Sprintf("[Hujjatlar konteksti:\n%s\n\nKO'RSATMA: Iltimos, faqat yuqoridagi hujjat bo'limlaridagi faktlarga tayanib javob bering va manba sahifa raqamlarini (masalan, [Sahifa N]) ko'rsating. Agar hujjatda so'ralgan ma'lumot bo'lmasa, uni to'qimasdan ochiq ayting.]", docContext)
	}
}

// Status text for SSE streaming
func GetStatusText(locale string, stage string) string {
	loc := strings.ToLower(locale)
	switch stage {
	case "generating":
		switch loc {
		case LocaleRU:
			return "Генерация ответа..."
		case LocaleEN:
			return "Generating response..."
		default:
			return "Javob tayyorlanmoqda..."
		}
	case "retrieving":
		switch loc {
		case LocaleRU:
			return "Поиск по страницам документа..."
		case LocaleEN:
			return "Searching document pages..."
		default:
			return "Hujjat sahifalaridan qidirilmoqda..."
		}
	default:
		return ""
	}
}

var dictionary = map[string]map[string]string{
	// Common Errors
	"ERR_INTERNAL": {
		LocaleUZ: "Tizimda kutilmagan xatolik yuz berdi. Iltimos, qayta urinib ko'ring.",
		LocaleRU: "Произошла непредвиденная ошибка системы. Пожалуйста, повторите попытку.",
		LocaleEN: "An unexpected system error occurred. Please try again.",
	},
	"ERR_MALFORMED_JSON": {
		LocaleUZ: "So'rov ma'lumotlari formati noto'g'ri.",
		LocaleRU: "Неверный формат данных запроса.",
		LocaleEN: "Invalid request data format.",
	},
	"ERR_UNAUTHORIZED": {
		LocaleUZ: "Ruxsat etilmagan kirish. Iltimos, tizimga qayta kiring.",
		LocaleRU: "Неавторизованный доступ. Пожалуйста, выполните вход.",
		LocaleEN: "Unauthorized access. Please log in again.",
	},
	"ERR_INVALID_CREDENTIALS": {
		LocaleUZ: "Email yoki parol noto'g'ri kiritildi.",
		LocaleRU: "Неверный адрес электронной почты или пароль.",
		LocaleEN: "Invalid email or password.",
	},
	"ERR_EMAIL_EXISTS": {
		LocaleUZ: "Ushbu email bilan ro'yxatdan o'tilgan foydalanuvchi allaqachon mavjud.",
		LocaleRU: "Пользователь с таким адресом электронной почты уже существует.",
		LocaleEN: "A user with this email address already exists.",
	},
	"ERR_INVALID_TOKEN": {
		LocaleUZ: "Sessiya muddati tugagan yoki token noto'g'ri. Qayta kiring.",
		LocaleRU: "Срок действия сессии истек или токен недействителен.",
		LocaleEN: "Session expired or invalid token. Please sign in again.",
	},
	"ERR_NOT_FOUND": {
		LocaleUZ: "So'ralgan ma'lumot topilmadi.",
		LocaleRU: "Запрашиваемые данные не найдены.",
		LocaleEN: "Requested resource not found.",
	},
	"ERR_DAILY_LIMIT": {
		LocaleUZ: "Bugungi bepul so'rovlar limitingiz tugadi. Cheksiz foydalanish uchun Pro tarifga o'ting.",
		LocaleRU: "Дневной лимит бесплатных запросов исчерпан. Перейдите на тариф Pro для продолжения.",
		LocaleEN: "Daily free request limit reached. Upgrade to Pro for unlimited access.",
	},
	"ERR_FILE_TOO_LARGE": {
		LocaleUZ: "Fayl hajmi ruxsat etilgan chegaradan oshib ketdi.",
		LocaleRU: "Размер файла превышает допустимый предел.",
		LocaleEN: "File size exceeds the allowed limit.",
	},
	"ERR_UNSUPPORTED_FILE": {
		LocaleUZ: "Faqat PDF, DOCX, TXT va rasm formatlari qo'llab-quvvatlanadi.",
		LocaleRU: "Поддерживаются только форматы PDF, DOCX, TXT и изображения.",
		LocaleEN: "Only PDF, DOCX, TXT, and image formats are supported.",
	},

	// Common Success Messages
	"SUCCESS_LOGOUT": {
		LocaleUZ: "Hisobdan muvaffaqiyatli chiqildi.",
		LocaleRU: "Вы успешно вышли из системы.",
		LocaleEN: "Successfully logged out.",
	},
	"SUCCESS_ACCOUNT_DELETED": {
		LocaleUZ: "Hisobingiz va barcha ma'lumotlaringiz butunlay o'chirildi.",
		LocaleRU: "Ваш аккаунт и все связанные данные были успешно удалены.",
		LocaleEN: "Your account and all associated data have been permanently deleted.",
	},
	"SUCCESS_LOCALE_UPDATED": {
		LocaleUZ: "Ilova tili muvaffaqiyatli yangilandi.",
		LocaleRU: "Язык приложения успешно обновлен.",
		LocaleEN: "Application language successfully updated.",
	},
}
