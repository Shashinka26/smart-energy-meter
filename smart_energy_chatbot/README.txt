========================================
  SMART ENERGY PROJECT - SETUP GUIDE
========================================

STEP 1 - INSTALL PACKAGES
--------------------------
Open terminal / command prompt and run:

    pip install flask openai scikit-learn joblib pandas requests

STEP 2 - GENERATE MODEL (First time only)
------------------------------------------
    python model.py

STEP 3 - RUN THE PROJECT
-------------------------
Open 3 separate terminals:

  Terminal 1 (Backend):
    python backend.py

  Terminal 2 (Chatbot GUI):
    python gui_chatbot.py

  Terminal 3 (Schedule UI):
    python schedule_ui.py

STEP 4 - TEST BACKEND
----------------------
  python test_send.py

========================================
NOTE: Add your OpenAI API key in ai_chatbot.py
      Replace: api_key="YOUR_KEY_HERE"
========================================
