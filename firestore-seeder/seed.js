const admin = require("firebase-admin");

const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});


const db = admin.firestore();

async function seedAbsent() {
    const userId = "RpszYulpziZtnSbddpPqCZs0HZT2";
    const docId = `${userId}_2026_05`;

    const buildDay = (dateStr, autoMarkedAt, autoMarkedBy) => ({
        userId,
        date: admin.firestore.Timestamp.fromDate(
            new Date(`${dateStr}T00:00:00+05:00`)
        ),
        dateString: dateStr,
        status: "absent",
        checkInTime: null,
        checkOutTime: null,
        breaks: [],
        totalWorkSeconds: 0,
        totalBreakSeconds: 0,
        autoMarkedAt,
        autoMarkedBy,
    });

    await db.collection("attendance_archive").doc(docId).set({
        userId,
        year: 2026,
        month: 5,

        days: {
            "2026-05-15": buildDay(
                "2026-05-15",
                "2026-05-15T08:01:00.000Z",
                "markAbsentAtSixPM"
            ),
            "2026-05-16": buildDay(
                "2026-05-16",
                "2026-05-16T08:01:00.000Z",
                "markAbsentAtCutoff"
            ),
            "2026-05-17": buildDay(
                "2026-05-17",
                "2026-05-17T08:01:00.000Z",
                "markAbsentAtCutoff"
            ),
            "2026-05-18": buildDay(
                "2026-05-18",
                "2026-05-18T08:01:00.000Z",
                "markAbsentAtCutoff"
            ),
            "2026-05-18": buildDay(
                "2026-05-18",
                "2026-05-18T08:01:00.000Z",
                "markAbsentAtCutoff"
            ),
        },
    });

    console.log("✅ Absent records inserted successfully");
}

seedAbsent().catch(console.error);