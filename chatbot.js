/* ============================================================
   EVENTARA - Assistant (floating chat widget)
   ------------------------------------------------------------
   Self-contained widget: injects its own styles + DOM on every
   page that includes this file. Prototype-grade conversational
   engine - intent matching + context awareness, no backend.

   ARCHITECTURE
     KB[]        -> the knowledge base. Add entries here to teach
                    the assistant something new. Nothing else needs
                    to change.
     getContext()-> current page, signed-in role, journey step.
     respond()   -> THE SEAM. Takes (text, ctx) and returns
                    {text, chips}. Swap this one function for a
                    server call (e.g. Claude API via your backend)
                    to upgrade to true LLM generation. Everything
                    else (UI, session, persistence) stays as-is.

   Session state lives in sessionStorage so the conversation
   survives page navigation but ends with the browser session.
   ============================================================ */
(function () {
  'use strict';
  if (window.__eventaraBotLoaded) return;
  window.__eventaraBotLoaded = true;

  var KEY = 'eventara_chat';
  var SUPPORT = 'support@eventara.in';

  /* ========================================================
     1. LANGUAGE HELPERS
     ======================================================== */
  var STOP = {};
  ('a an the is are am was were do does did i my me you your we our it this that of to for on in at with and or if can could would should how what where when who why please tell show help need want get got there here be been has have had will just about from as by so any some').split(' ')
    .forEach(function (w) { STOP[w] = 1; });

  // many words -> one canonical term used by the KB
  var CANON = {};
  function alias(canonical, words) { words.forEach(function (w) { CANON[w] = canonical; }); CANON[canonical] = canonical; }
  alias('supplier', ['vendor', 'vendors', 'suppliers', 'venue', 'venues', 'hotel', 'hotels', 'planner', 'planners', 'organiser', 'organisers', 'organizer', 'organizers', 'provider', 'providers', 'resort', 'resorts', 'banquet']);
  alias('quote', ['quotation', 'quotations', 'quotes', 'estimate', 'estimates', 'bid', 'bids']);
  alias('book', ['booking', 'bookings', 'reserve', 'reservation', 'booked']);
  alias('cancel', ['cancellation', 'cancellations', 'cancelling', 'canceling', 'cancelled']);
  alias('refund', ['refunds', 'refunded', 'moneyback']);
  alias('payment', ['pay', 'paying', 'payments', 'paid', 'checkout']);
  alias('deposit', ['advance', 'upfront', 'token']);
  alias('signin', ['login', 'log', 'signin', 'sign', 'logon']);
  alias('account', ['profile', 'accounts']);
  alias('password', ['passwords', 'passcode']);
  alias('register', ['registration', 'signup', 'join', 'onboard', 'enrol', 'enroll', 'become']);
  alias('verify', ['verification', 'verified', 'verifying', 'badge', 'kyc']);
  alias('availability', ['calendar', 'dates', 'available', 'slot', 'slots']);
  alias('enquiry', ['inquiry', 'inquiries', 'enquiries', 'lead', 'leads', 'request', 'requests']);
  alias('portfolio', ['photos', 'photo', 'images', 'gallery', 'pictures']);
  alias('payout', ['payouts', 'earnings', 'settlement', 'disbursement']);
  alias('commission', ['commissions', 'cut', 'margin']);
  alias('dashboard', ['portal', 'panel', 'console']);
  alias('filter', ['filters', 'filtering', 'narrow', 'refine']);
  alias('compare', ['comparison', 'comparing']);
  alias('review', ['reviews', 'rating', 'ratings', 'feedback']);
  alias('invoice', ['invoices', 'bill', 'billing', 'gst', 'tax', 'taxes', 'receipt']);
  alias('support', ['helpdesk', 'agent', 'human', 'representative', 'contact']);
  alias('wedding', ['weddings', 'marriage', 'shaadi', 'shadi']);
  alias('corporate', ['company', 'office', 'offsite', 'offsites', 'business']);
  alias('conference', ['conferences', 'seminar', 'seminars', 'summit']);
  alias('institutional', ['institution', 'institutions', 'college', 'colleges', 'university', 'universities', 'school', 'schools', 'fest', 'fests', 'convocation', 'campus']);
  alias('price', ['pricing', 'prices', 'cost', 'costs', 'rate', 'rates', 'budget', 'charges', 'charge']);
  alias('free', ['freely', 'gratis']);
  alias('category', ['categories', 'type', 'types', 'kind', 'kinds']);
  alias('secure', ['security', 'safe', 'safety', 'protected', 'protection']);
  alias('privacy', ['private', 'data', 'personal', 'confidential']);
  alias('fraud', ['scam', 'scams', 'fake', 'suspicious', 'report', 'cheat']);
  alias('bug', ['error', 'errors', 'broken', 'issue', 'issues', 'problem', 'problems', 'glitch']);
  alias('listing', ['list', 'listings', 'property', 'properties']);
  alias('work', ['works', 'working']);
  alias('delete', ['remove', 'close', 'deactivate', 'deletion']);
  alias('update', ['edit', 'change', 'modify', 'amend']);
  alias('negotiate', ['negotiation', 'bargain', 'discount', 'haggle']);
  // NB: deliberately NOT aliasing 'udaipur' here - it appears in many
  // supplier-search queries and would fight the 'find' intent.
  alias('city', ['cities', 'delhi', 'mumbai', 'jaipur', 'bengaluru', 'bangalore', 'pune',
                 'hyderabad', 'chennai', 'kolkata', 'goa', 'ahmedabad', 'gurgaon', 'noida',
                 'location', 'locations', 'region', 'regions', 'elsewhere']);

  function normalize(s) {
    return (' ' + String(s || '').toLowerCase() + ' ')
      .replace(/[^a-z0-9\s]/g, ' ')
      .replace(/\s+/g, ' ');
  }
  function stem(w) {
    if (w.length > 4 && /[^s]s$/.test(w)) return w.slice(0, -1);
    return w;
  }
  function tokens(s) {
    return normalize(s).trim().split(' ')
      .filter(function (w) { return w && !STOP[w]; })
      .map(stem)
      .map(function (w) { return CANON[w] || w; });
  }

  /* ========================================================
     2. CONTEXT - which page, who is the user, where are they
     ======================================================== */
  var PAGES = {
    'index': { name: 'the home page', chips: ['What is Eventara?', 'What events are supported?', 'Get free quotes'] },
    'search': { name: 'Find Suppliers', chips: ['How do I filter?', 'How do I request a quote?', 'How do I compare?'] },
    'provider': { name: 'a supplier profile', chips: ['How do I book this venue?', 'Request a quote', 'Is my payment safe?'] },
    'brief': { name: 'Get Free Quotes', chips: ['What happens after I request?', 'How are prices decided?', 'Can I negotiate?'] },
    'compare': { name: 'Compare Quotes', chips: ['How do I choose?', 'What deposit do I pay?', 'Can I negotiate?'] },
    'booking': { name: 'Confirm Booking', chips: ['Is my payment safe?', 'What deposit do I pay?', 'Cancellation policy'] },
    'invoice': { name: 'your invoice & booking record', chips: ['GST invoice', 'Is my payment safe?', 'Where are my bookings?'] },
    'signin': { name: 'Sign In / Register', chips: ['How do I create an account?', "I can't log in", 'Register as a business'] },
    'customer-dashboard': { name: 'your account', chips: ['Where are my bookings?', 'Track my quotes', 'Update my profile'] },
    'dashboard': { name: 'your business portal', chips: ['How do I respond to an enquiry?', 'Manage availability', 'How do payouts work?'] },
    'faq': { name: 'the Help Centre', chips: ['How do I book a venue?', 'What payment methods?', 'Contact support'] },
    'ops': { name: 'the operations console', chips: ['What is Eventara?', 'Contact support'] }
  };

  function getContext() {
    var file = (location.pathname.split('/').pop() || 'index.html').replace('.html', '');
    if (!file || !PAGES[file]) file = PAGES[file] ? file : (file || 'index');
    var page = PAGES[file] ? file : 'index';
    var session = null;
    try { session = window.Auth && window.Auth.getSession ? window.Auth.getSession() : null; } catch (e) {}
    return {
      page: page,
      pageName: (PAGES[page] || PAGES.index).name,
      chips: (PAGES[page] || PAGES.index).chips,
      signedIn: !!session,
      role: session ? session.role : null,       // 'customer' | 'supplier' | null
      name: session ? session.name : null
    };
  }

  /* ========================================================
     3. KNOWLEDGE BASE
        k    = canonical keywords (see CANON above)
        p    = strong phrases (exact substring, big score bonus)
        aud  = 'customer' | 'supplier' | 'both'
        a    = answer: string OR function(ctx) -> string
        chips= follow-up quick replies
     ======================================================== */
  var L = {
    search: '<a href="search.html">Find Suppliers</a>',
    brief: '<a href="brief.html">Get Free Quotes</a>',
    compare: '<a href="compare.html">Compare Quotes</a>',
    faq: '<a href="faq.html">Help Centre</a>',
    reg: '<a href="signin.html?mode=register&type=business">List Your Business</a>',
    signin: '<a href="signin.html">Sign In</a>',
    cdash: '<a href="customer-dashboard.html">My Account</a>',
    sdash: '<a href="supplier-dashboard.html">business portal</a>',
    mail: '<a href="mailto:' + SUPPORT + '">' + SUPPORT + '</a>'
  };

  var KB = [
    /* ---------------- PLATFORM ---------------- */
    { id: 'what', aud: 'both', k: ['eventara', 'platform'], p: ['what is eventara', 'about eventara', 'tell me about'],
      a: "Eventara is Udaipur's trusted marketplace for events. We connect people planning events with verified venues, hotels and event planners - so you can compare clear quotes side by side and book with your payment protected until your event is delivered.",
      chips: ['How does it work?', 'What events are supported?', 'Is it free?'] },

    { id: 'how', aud: 'both', k: ['work'], p: ['how does eventara work', 'how does it work', 'how it works'],
      a: "It's three steps:<br><b>1.</b> Tell us about your event (type, date, guests, budget).<br><b>2.</b> A few matched venues/planners send itemised quotes - usually within 48 hours.<br><b>3.</b> Pick one and pay a small deposit. It's held safely and released only after your event.<br><br>Start here: " + L.brief,
      chips: ['Find suppliers', 'What deposit do I pay?'] },

    { id: 'scope', aud: 'both', k: ['category', 'scope', 'phase', 'launch', 'corporate', 'conference', 'institutional'], p: ['what event categories', 'which events', 'currently available', 'what events are supported', 'what do you cover'],
      a: "Right now Eventara covers two categories:<br><b>• Corporate Events &amp; Conferences</b> - offsites, conferences, product launches, award nights (typically from ₹5 lakh).<br><b>• Institutional Events &amp; Fests</b> - college fests, convocations, school annual days (typically from ₹2.5 lakh).<br><br>Weddings &amp; related celebrations are coming soon.",
      chips: ['Find suppliers', 'Get free quotes', 'What about weddings?'] },

    { id: 'wedding', aud: 'both', k: ['wedding'], p: ['about weddings', 'wedding venue', 'book a wedding'],
      a: "Weddings &amp; related celebrations are <b>coming soon</b> - they're planned for our next phase, so you can't browse or book wedding venues on Eventara just yet.<br><br>Today we cover corporate events &amp; conferences and institutional events &amp; fests.",
      chips: ['What events are supported?', 'Contact support'] },

    { id: 'free', aud: 'both', k: ['free'], p: ['is eventara free', 'does it cost', 'any fees', 'do you charge'],
      a: "Eventara is <b>free for customers</b> - browsing, requesting quotes and comparing costs you nothing.<br><br>Businesses list for free too. We earn a small commission only on confirmed bookings - no listing or subscription fees.",
      chips: ['How are commissions handled?', 'List your business'] },

    { id: 'cities', aud: 'both', k: ['city'],
      p: ['which cities', 'what cities', 'other cities', 'outside udaipur', 'services in',
          'service in', 'operate in', 'available in', 'do you serve', 'do you cover',
          'only in udaipur', 'apart from udaipur', 'besides udaipur'],
      a: "Right now Eventara operates in <b>Udaipur only</b>. Every venue and planner on the platform is a verified Udaipur business, and bookings are for events held in Udaipur - we're not live in other cities yet.<br><br>If you're planning an event in Udaipur, start with " + L.brief + ".",
      chips: ['What events are supported?', 'Find suppliers', 'Contact support'] },

    { id: 'who', aud: 'both', k: [], p: ['who can use', 'who is it for'],
      a: "Both sides of an event. <b>Customers</b> - companies and institutions planning events - find and book trusted suppliers. <b>Businesses</b> - hotels, venues and event planners - reach genuine customers and win bookings.",
      chips: ['Find suppliers', 'List your business'] },

    /* ---------------- CUSTOMER JOURNEY ---------------- */
    { id: 'find', aud: 'customer', k: ['supplier'], p: ['find me', 'find hotels', 'show me', 'browse', 'looking for', 'find a venue'],
      flow: 'event_type_find',
      a: "You can browse every verified venue and planner on " + L.search + ".",
      chips: ['How do I filter?', 'How do I request a quote?'] },

    { id: 'filter', aud: 'customer', k: ['filter'], p: ['how do i filter', 'narrow down'],
      a: "On " + L.search + " you can filter by <b>event type</b>, <b>guest count</b> and <b>budget</b>, switch between <b>Banquet Hotels</b> and <b>Event Managers</b>, and sort by rating or price. The result count updates as you go.",
      chips: ['How do I compare?', 'Get free quotes'] },

    { id: 'compare', aud: 'customer', k: ['compare'], p: ['compare quotes', 'side by side', 'how do i choose'],
      a: "Once your quotes arrive, " + L.compare + " lines them up side by side against what you asked for - price, inclusions, capacity and rating. Anything a supplier left out is flagged, so you can compare fairly.",
      chips: ['Can I negotiate?', 'What deposit do I pay?'] },

    { id: 'quote', aud: 'customer', k: ['quote'], p: ['request a quote', 'how do i request', 'get a quote', 'ask for pricing'],
      flow: 'event_type_quote',
      a: "Use " + L.brief + " - tell us your event type, date, guest count and budget. Your request goes to a few matched venues and planners, and their quotes arrive within 48 hours.",
      chips: ['What happens after I request?', 'How are prices decided?'] },

    { id: 'after', aud: 'customer', k: [], p: ['what happens after', 'after i request', 'after i submit', 'after i send'],
      a: "Your request goes straight to the matched businesses. Their quotes usually arrive <b>within 48 hours</b>, and we line them up side by side on " + L.compare + " so you can compare without any back-and-forth.",
      chips: ['How do I choose?', 'Are bookings instant?'] },

    { id: 'prices', aud: 'customer', k: ['price'], p: ['how are prices', 'how is pricing', 'who decides price'],
      a: "Each business sets its own pricing based on your requirements - guest count, date, inclusions and services. You get <b>itemised</b> quotes, so you can see exactly what's included and compare fairly.",
      chips: ['Can I negotiate?', 'What deposit do I pay?'] },

    { id: 'negotiate', aud: 'customer', k: ['negotiate'], p: ['can i negotiate'],
      a: "Yes. You can message a business through Eventara to discuss inclusions, tweak a package or talk pricing. Your contact details stay private until you decide to book.",
      chips: ['How do I book?', 'How do I compare?'] },

    { id: 'bookhow', aud: 'customer', k: ['book'], p: ['how do i book', 'book a venue', 'how to book'],
      a: "Browse or request quotes, compare what comes back, then pick one and pay a small deposit to confirm. That's it - your booking, invoice and details are saved to your account.<br><br>Start with " + L.brief + ".",
      chips: ['What deposit do I pay?', 'Are bookings instant?', 'Cancellation policy'] },

    { id: 'instant', aud: 'customer', k: [], p: ['bookings confirmed instantly', 'instant booking', 'are bookings instant', 'confirmed instantly'],
      a: "A booking is confirmed the moment you accept a quote and pay the deposit. The business is notified immediately, and your deposit stays held safely until your event takes place.",
      chips: ['Is my payment safe?', 'Cancellation policy'] },

    { id: 'multi', aud: 'customer', k: [], p: ['multiple vendors', 'more than one', 'several vendors', 'book multiple'],
      a: "Yes - you can request quotes from several venues and planners, shortlist and compare them, and book more than one supplier for the same event (say a venue plus a separate planner).",
      chips: ['How do I compare?', 'Get free quotes'] },

    { id: 'mybookings', aud: 'customer', k: ['book', 'dashboard'], p: ['my bookings', 'booking history', 'where are my bookings', 'find my booking', 'past bookings'],
      a: function (ctx) {
        if (ctx.role === 'customer') return "They're in " + L.cdash + " → <b>My Bookings</b>, along with your requests, quotes, invoices and saved suppliers.";
        return "Your bookings live in your account. " + L.signin + " and open <b>My Account → My Bookings</b> to see them, along with your quotes and invoices.";
      },
      chips: ['How do I cancel?', 'Where is my invoice?'] },

    { id: 'cancel', aud: 'customer', k: ['cancel'], p: ['cancel my booking', 'cancellation policy', 'cancellation charges'],
      a: "You can cancel or change a booking from <b>My Bookings</b>. Charges depend on timing - a typical policy is a full refund 30+ days before, partial 15–30 days before, and no refund under 15 days (but you never pay the balance). The exact terms are shown on each booking before you pay.",
      chips: ['How do refunds work?', 'Contact support'] },

    { id: 'refund', aud: 'both', k: ['refund'], p: ['how do refunds', 'get my money back'],
      a: "Refunds follow each booking's cancellation terms, which you see before you pay. Cancel far enough ahead and your deposit comes back in full or in part. If an event doesn't go to plan, your money stays protected until our team resolves it.",
      chips: ['Cancellation policy', 'Contact support'] },

    { id: 'review', aud: 'both', k: ['review'], p: ['leave a review', 'how do reviews'],
      a: "Only customers who actually booked through Eventara can leave a review - so every rating you see comes from a real event. You'll be invited to review after your event is delivered.",
      chips: ['Are suppliers verified?'] },

    /* ---------------- PAYMENTS ---------------- */
    { id: 'paymethods', aud: 'both', k: ['payment'], p: ['payment methods', 'how can i pay', 'what payment', 'upi', 'net banking'],
      a: "You can pay by <b>UPI</b> (GPay, PhonePe, BHIM), <b>net banking</b> or major <b>debit/credit cards</b>. Businesses receive payouts straight to their registered bank account.",
      chips: ['Is my payment safe?', 'What deposit do I pay?'] },

    { id: 'deposit', aud: 'both', k: ['deposit'], p: ['what deposit', 'how much deposit', 'why deposit'],
      a: "A small deposit - usually around <b>30%</b> - confirms your booking. It's held safely by Eventara (not paid straight to the supplier), and the balance is settled per your booking terms.",
      chips: ['Is my payment safe?', 'Cancellation policy'] },

    { id: 'secure', aud: 'both', k: ['secure'], p: ['is my payment safe', 'payment security', 'is it safe'],
      a: "Yes. Your money is held safely by Eventara and released to the business <b>only after your event is delivered</b> - never before. Every transaction runs through a secure gateway and money never moves off-platform.",
      chips: ['What deposit do I pay?', 'How do refunds work?'] },

    { id: 'invoice', aud: 'both', k: ['invoice'], p: ['gst invoice', 'do i get an invoice', 'tax invoice', 'where is my invoice'],
      a: "Every confirmed booking comes with a proper <b>GST invoice</b> and a full booking record - ready the moment you pay, and easy to download and keep for yourself or your company. You'll find it on the booking in your account.",
      chips: ['Where are my bookings?', 'Payment methods'] },

    /* ---------------- ACCOUNT ---------------- */
    { id: 'create', aud: 'both', k: ['register', 'account'], p: ['create an account', 'sign up', 'how do i register', 'make an account'],
      a: "Head to " + L.signin + " → <b>Register</b>, then choose <b>Customer</b> (planning an event) or <b>Business/Supplier</b> (hotel, venue or planner). It's a short form and you're in.",
      chips: ['Register as a business', "I can't log in"] },

    { id: 'login', aud: 'both', k: ['signin'], p: ["can't log in", 'cant log in', 'unable to login', 'login issue', 'login problem', 'trouble signing in'],
      a: "Sorry about that. Check your email and password and that Caps Lock is off. If you've forgotten it, use <b>Forgot Password?</b> on " + L.signin + " to reset. Still stuck? Email " + L.mail + " and we'll sort it out.",
      chips: ['Reset my password', 'Contact support'] },

    { id: 'password', aud: 'both', k: ['password'], p: ['reset my password', 'forgot password', 'change password'],
      a: "On " + L.signin + ", click <b>Forgot Password?</b> and follow the instructions we email you to set a new one.",
      chips: ["I can't log in", 'Contact support'] },

    { id: 'profile', aud: 'both', k: ['account', 'update'], p: ['update my profile', 'edit my profile', 'change my details'],
      a: function (ctx) {
        if (ctx.role === 'supplier') return "Open your " + L.sdash + " and edit your business profile - name, contact, photos, packages and documents.";
        if (ctx.role === 'customer') return "Open " + L.cdash + " → <b>My Profile</b> to update your name, contact details, GST number and preferences.";
        return L.signin + " first, then open <b>My Account → My Profile</b> to update your name, contact details and preferences.";
      },
      chips: ['Where are my bookings?', 'Delete my account'] },

    { id: 'delete', aud: 'both', k: ['delete'], p: ['delete my account', 'close my account', 'remove my account'],
      a: "Email " + L.mail + " and we'll close your account and remove your data in line with our Privacy Policy. Some records may be kept where the law requires it.",
      chips: ['Privacy', 'Contact support'] },

    /* ---------------- SUPPLIER JOURNEY ---------------- */
    { id: 'become', aud: 'supplier', k: ['register', 'listing'], p: ['become a vendor', 'become an event planner', 'become a supplier', 'list my business', 'register as a vendor', 'join as a', 'list my property', 'list my hotel'],
      a: "Great - click " + L.reg + ", choose <b>Business/Supplier</b>, and submit your business details (name, type, contact, GST). Our team verifies you, and once approved you get a <b>verified badge</b> and go live to customers.<br><br>There are no listing fees - we take a small commission only on confirmed bookings.",
      chips: ['How does verification work?', 'How do payouts work?', 'How are commissions handled?'] },

    { id: 'onboard', aud: 'supplier', k: ['verify'], p: ['how does onboarding', 'verification process', 'how are vendors verified', 'get verified', 'verified badge'],
      a: "After you register, the Eventara team checks your documents - identity, <b>GST</b> and the relevant trade or food-safety licences. Once approved, your verified badge goes live and customers can find you. It's handled by our ops team, so there's nothing technical for you to do.",
      chips: ['List your business', 'How do I get enquiries?'] },

    { id: 'listing', aud: 'supplier', k: ['listing'], p: ['list my services', 'add my property', 'manage rooms', 'manage halls', 'add packages'],
      a: "From your " + L.sdash + " you can add your property details, each hall or room with its capacity and inclusions, your package tiers and pricing - and edit them any time.",
      chips: ['Manage availability', 'Update my portfolio'] },

    { id: 'availability', aud: 'supplier', k: ['availability'], p: ['manage availability', 'block dates', 'my calendar'],
      a: "Use the <b>availability calendar</b> in your " + L.sdash + " to mark dates open or blocked - so you only receive enquiries for dates you can actually serve, and avoid double-bookings.",
      chips: ['How do I get enquiries?', 'Manage my listing'] },

    { id: 'enquiry', aud: 'supplier', k: ['enquiry'], p: ['receive enquiries', 'get enquiries', 'booking inquiries', 'respond to customer', 'how do i respond'],
      a: "Matched customer requests land in your <b>enquiry inbox</b> in the " + L.sdash + ", and you're notified. Open one, build a quote with your inclusions and price, and send it. Replying <b>within 48 hours</b> keeps your rating high and wins more bookings.",
      chips: ['Manage availability', 'How do payouts work?'] },

    { id: 'portfolio', aud: 'supplier', k: ['portfolio'], p: ['update my portfolio', 'add photos', 'change my photos'],
      a: "Add photos, packages, capacities and details any time from your " + L.sdash + ". A rich, up-to-date portfolio directly improves how often customers shortlist you.",
      chips: ['Manage my listing', 'How do I get enquiries?'] },

    { id: 'payout', aud: 'supplier', k: ['payout'], p: ['how do payouts', 'when do i get paid', 'my earnings'],
      a: "The customer's deposit is held safely by Eventara and released to you <b>after the event is delivered</b>, net of commission - or automatically 72 hours after the event if nothing is flagged. Payouts go to your registered bank account.",
      chips: ['How are commissions handled?', 'How do I get enquiries?'] },

    { id: 'commission', aud: 'supplier', k: ['commission'], p: ['how are commissions', 'what commission', 'your cut'],
      a: "Eventara charges a <b>small commission only on confirmed bookings</b>. It's deducted from your payout automatically - no upfront, listing or subscription fees. You only pay when you earn.",
      chips: ['How do payouts work?', 'List your business'] },

    /* ---------------- TRUST & SAFETY ---------------- */
    { id: 'verified', aud: 'customer', k: ['verify'], p: ['are suppliers verified', 'are vendors verified', 'is it trustworthy', 'can i trust'],
      a: "Every business on Eventara is identity-checked and licence-verified (including GST) before it can list, and carries a <b>verified badge</b>. Plus only customers who actually booked can leave reviews - so ratings are genuine.",
      chips: ['Is my payment safe?', 'Report suspicious activity'] },

    { id: 'fraud', aud: 'both', k: ['fraud'], p: ['report suspicious', 'report a vendor', 'is this a scam'],
      a: "Use the <b>Report</b> option on any listing or message, or email " + L.mail + ". We investigate every report. Contact details stay private until booking and payments are held on-platform - which removes most of the risk up front.",
      chips: ['Is my payment safe?', 'Contact support'] },

    { id: 'privacy', aud: 'both', k: ['privacy'], p: ['my data', 'data privacy', 'is my data safe', 'privacy policy'],
      a: "We collect only what's needed to run your bookings, never sell your data, and never share your contact details without your consent - they stay private until you book.",
      chips: ['Is my payment safe?', 'Delete my account'] },

    /* ---------------- SUPPORT ---------------- */
    { id: 'support', aud: 'both', k: ['support'], p: ['contact support', 'talk to a human', 'speak to someone', 'customer support', 'need help', 'real person'],
      a: "Happy to hand you over. Email <b>" + L.mail + "</b> - our team is available <b>9 am–8 pm IST, Mon–Sat</b>, and urgent event-day issues are handled around the clock. You can also browse the " + L.faq + ".",
      chips: ['Support hours', 'Report a bug'] },

    { id: 'hours', aud: 'both', k: ['hours'], p: ['support hours', 'when are you open', 'business hours'],
      a: "Our support team is available <b>9 am–8 pm IST, Monday to Saturday</b>. Urgent, event-day booking issues are handled 24/7.",
      chips: ['Contact support'] },

    { id: 'escalate', aud: 'both', k: ['escalate'], p: ['escalate', 'complaint', 'speak to a manager', 'not resolved'],
      a: "If something isn't resolved, just ask to escalate when you email " + L.mail + " - a senior team member will follow up, and event-day problems always get priority.",
      chips: ['Contact support'] },

    { id: 'bug', aud: 'both', k: ['bug'], p: ['report a bug', 'something is broken', 'not working', 'technical issue'],
      a: "Sorry about that. Email " + L.mail + " with a short description and a screenshot if you can - it goes straight to our team. For login or payment trouble we can usually help right away.",
      chips: ["I can't log in", 'Contact support'] },

    { id: 'faq', aud: 'both', k: [], p: ['faq', 'help centre', 'help center', 'frequently asked'],
      a: "Our " + L.faq + " has 50 answers across General, Booking, Payments, Account, Vendors, Hotels &amp; Venues, Trust &amp; Safety and Support - with a search box.",
      chips: ['Contact support'] },

    /* ---------------- SMALL TALK ---------------- */
    { id: 'hi', aud: 'both', k: [], p: ['hi', 'hello', 'hey', 'good morning', 'good evening', 'namaste'], exact: true,
      a: function (ctx) { return "Hello" + (ctx.name ? ' ' + ctx.name.split(' ')[0] : '') + "! How can I help you today?"; } },
    { id: 'thanks', aud: 'both', k: [], p: ['thanks', 'thank you', 'thankyou', 'cheers', 'appreciate'], exact: true,
      a: "You're very welcome! Anything else I can help with?" },
    { id: 'bye', aud: 'both', k: [], p: ['bye', 'goodbye', 'see you'], exact: true,
      a: "Goodbye - and good luck with your event! I'm here whenever you need me." },
    { id: 'who_r_u', aud: 'both', k: [], p: ['who are you', 'are you a bot', 'are you human', 'are you real'],
      a: "I'm the Eventara Assistant - an automated helper. I can explain how the platform works, guide you through booking or listing, and answer FAQs. For anything I can't handle, I'll point you to our team at " + L.mail + "." }
  ];

  /* ========================================================
     4. THE ENGINE  --  respond(text, ctx) -> {text, chips}
        >>> Swap this function for a server/LLM call to upgrade.
     ======================================================== */
  var convo = { pending: null, misses: 0, last: null };

  var EVENT_TYPES = ['corporate', 'conference', 'institutional'];

  function scoreEntry(e, tks, text, ctx) {
    var s = 0;
    (e.p || []).forEach(function (p) {
      if (e.exact) {
        var t = text.trim();
        if (t === p || t === p + '!' || t === p + '.') s += 8;
      } else if (text.indexOf(' ' + p + ' ') !== -1 || text.indexOf(' ' + p) !== -1) s += 6;
    });
    (e.k || []).forEach(function (k) { if (tks.indexOf(k) !== -1) s += 3; });
    if (s > 0) {
      if (e.aud !== 'both' && ctx.role && e.aud === ctx.role) s += 1.5;
      if (e.aud !== 'both' && ctx.role && e.aud !== ctx.role) s -= 0.5;
      // page nudges
      if (ctx.page === 'dashboard' && e.aud === 'supplier') s += 1;
      if (ctx.page === 'search' && (e.id === 'filter' || e.id === 'find')) s += 1;
      if (ctx.page === 'booking' && (e.id === 'deposit' || e.id === 'secure')) s += 1;
      if (ctx.page === 'signin' && (e.id === 'create' || e.id === 'login')) s += 1;
    }
    return s;
  }

  function answerOf(e, ctx) { return typeof e.a === 'function' ? e.a(ctx) : e.a; }

  function detectEventType(tks) {
    for (var i = 0; i < EVENT_TYPES.length; i++) if (tks.indexOf(EVENT_TYPES[i]) !== -1) return EVENT_TYPES[i];
    return null;
  }

  function respond(raw, ctx) {
    var text = normalize(raw);
    var tks = tokens(raw);

    /* --- multi-turn: we asked which event type --- */
    if (convo.pending && convo.pending.slot === 'event_type') {
      var et = detectEventType(tks);
      if (tks.indexOf('wedding') !== -1) {
        convo.pending = null;
        var w = KB.filter(function (x) { return x.id === 'wedding'; })[0];
        return { text: answerOf(w, ctx), chips: w.chips };
      }
      if (et) {
        var goal = convo.pending.goal;
        convo.pending = null;
        var label = et === 'corporate' ? 'corporate events' : et === 'conference' ? 'conferences' : 'institutional events &amp; fests';
        if (goal === 'quotes') {
          return { text: "Perfect - for <b>" + label + "</b>, open " + L.brief + " and fill in your date, guest count and budget. Your request goes to a few matched venues and planners, and quotes arrive within 48 hours.",
                   chips: ['What happens after I request?', 'How are prices decided?'] };
        }
        return { text: "Great - for <b>" + label + "</b>, head to " + L.search + " and set the <b>Event Type</b> filter. You can also filter by guest count and budget, and switch between Banquet Hotels and Event Managers.<br><br>Prefer quotes to come to you? Try " + L.brief + ".",
                 chips: ['How do I filter?', 'How do I request a quote?'] };
      }
      // not an event type - drop the slot and answer normally
      convo.pending = null;
    }

    /* --- score the KB --- */
    var best = null, bestScore = 0, runners = [];
    KB.forEach(function (e) {
      var s = scoreEntry(e, tks, text, ctx);
      if (s > bestScore) { bestScore = s; best = e; }
      if (s > 0) runners.push({ e: e, s: s });
    });

    if (best && bestScore >= 3) {
      convo.misses = 0;
      convo.last = best.id;

      // start a follow-up flow when the user was vague
      if (best.flow && !detectEventType(tks)) {
        convo.pending = { slot: 'event_type', goal: best.flow === 'event_type_quote' ? 'quotes' : 'find' };
        return {
          text: "Happy to help. What kind of event is it?",
          chips: ['Corporate event', 'Conference', 'Institutional fest']
        };
      }
      return { text: answerOf(best, ctx), chips: best.chips || ctx.chips };
    }

    /* --- weak match: ask to clarify, offer the closest topics --- */
    if (best && bestScore >= 1.5) {
      runners.sort(function (a, b) { return b.s - a.s; });
      var opts = runners.slice(0, 3).map(function (r) { return r.e; });
      return {
        text: "I'm not certain I understood. Did you mean one of these?",
        chips: opts.map(function (e) { return (e.chips && e.chips[0]) ? topicLabel(e) : topicLabel(e); }).filter(Boolean)
      };
    }

    /* --- fallback: never invent an answer --- */
    convo.misses++;
    var extra = convo.misses >= 2
      ? "<br><br>It might be quicker to talk to a person - email " + L.mail + " (9 am–8 pm IST, Mon–Sat)."
      : "";
    return {
      text: "I don't have enough information to answer that confidently, and I'd rather not guess.<br><br>You can search all 50 answers in our " + L.faq + ", or I can point you in the right direction." + extra,
      chips: ['What is Eventara?', 'How does it work?', 'Contact support']
    };
  }

  var LABELS = {
    what: 'What is Eventara?', how: 'How does it work?', scope: 'What events are supported?',
    wedding: 'What about weddings?', free: 'Is it free?', find: 'Find suppliers', filter: 'How do I filter?',
    compare: 'How do I compare?', quote: 'How do I request a quote?', bookhow: 'How do I book?',
    mybookings: 'Where are my bookings?', cancel: 'How do I cancel?', refund: 'How do refunds work?',
    paymethods: 'Payment methods', deposit: 'What deposit do I pay?', secure: 'Is my payment safe?',
    invoice: 'GST invoice', create: 'How do I create an account?', login: "I can't log in",
    password: 'Reset my password', profile: 'Update my profile', delete: 'Delete my account',
    become: 'List your business', onboard: 'How does verification work?', listing: 'Manage my listing',
    availability: 'Manage availability', enquiry: 'How do I get enquiries?', portfolio: 'Update my portfolio',
    payout: 'How do payouts work?', commission: 'How are commissions handled?', verified: 'Are suppliers verified?',
    fraud: 'Report suspicious activity', privacy: 'Privacy', support: 'Contact support', hours: 'Support hours',
    bug: 'Report a bug', faq: 'Help Centre', review: 'How do reviews work?', prices: 'How are prices decided?',
    negotiate: 'Can I negotiate?', instant: 'Are bookings instant?', multi: 'Can I book multiple vendors?',
    after: 'What happens after I request?', who: 'Who can use Eventara?', escalate: 'Escalate an issue'
  };
  function topicLabel(e) { return LABELS[e.id] || null; }

  /* ========================================================
     4b. REMOTE BRAIN - /api/chat (Claude, server-side key)
         Falls back to the local engine above whenever the
         endpoint is absent (static hosting), unconfigured,
         or erroring. The widget therefore works everywhere.
     ======================================================== */
  var API_URL = '/api/chat';
  var apiState = 'unknown';           // 'unknown' | 'on' | 'off'

  function stripHtml(h) {
    var d = document.createElement('div');
    d.innerHTML = h;
    return (d.textContent || '').replace(/\s+/g, ' ').trim();
  }

  function history() {
    return msgs.slice(-12).map(function (m) {
      return { role: m.r === 'user' ? 'user' : 'assistant', content: stripHtml(m.t) };
    }).filter(function (m) { return m.content; });
  }

  function respondRemote(ctx) {
    var ctrl = typeof AbortController !== 'undefined' ? new AbortController() : null;
    var timer = ctrl ? setTimeout(function () { ctrl.abort(); }, 20000) : null;
    return fetch(API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ messages: history(), context: ctx }),
      signal: ctrl ? ctrl.signal : undefined
    }).then(function (r) {
      if (timer) clearTimeout(timer);
      // No working endpoint here (static host, or no API key configured)
      // -> stop probing for the rest of the session.
      if (r.status === 404 || r.status === 405 || r.status === 501 || r.status === 503) {
        apiState = 'off';
        return null;
      }
      if (!r.ok) return null;                    // transient: fall back just this once
      apiState = 'on';
      return r.json();
    }).then(function (d) {
      return (d && d.text) ? { text: d.text, chips: ctx.chips } : null;
    }).catch(function () {
      if (timer) clearTimeout(timer);
      return null;
    });
  }

  /* ========================================================
     5. UI
     ======================================================== */
  var css = ''
    + '.evb-fab{position:fixed;right:20px;bottom:20px;width:58px;height:58px;border-radius:50%;background:var(--coral,#1E40AF);color:#fff;border:none;cursor:pointer;box-shadow:0 6px 20px rgba(0,0,0,.18);display:flex;align-items:center;justify-content:center;z-index:9998;transition:transform .2s ease,opacity .2s ease}'
    + '.evb-fab:hover{transform:scale(1.06)}'
    + '.evb-fab svg{width:26px;height:26px}'
    + '.evb-fab .evb-dot{position:absolute;top:2px;right:2px;width:12px;height:12px;border-radius:50%;background:var(--gold,#CBA135);border:2px solid #fff}'
    + '.evb-fab.evb-hidden{opacity:0;pointer-events:none;transform:scale(.8)}'
    + '.evb-panel{position:fixed;right:20px;bottom:20px;width:380px;max-width:calc(100vw - 32px);height:580px;max-height:calc(100vh - 40px);background:var(--surface,#fff);border:1px solid var(--hairline,#ddd);border-radius:16px;box-shadow:0 12px 40px rgba(0,0,0,.18);display:flex;flex-direction:column;overflow:hidden;z-index:9999;opacity:0;transform:translateY(12px) scale(.98);pointer-events:none;transition:opacity .22s ease,transform .22s ease;font-family:var(--font-body,Inter,system-ui,sans-serif)}'
    + '.evb-panel.evb-open{opacity:1;transform:none;pointer-events:auto}'
    + '.evb-head{display:flex;align-items:center;gap:10px;padding:14px 14px;border-bottom:1px solid var(--hairline-light,#ebebeb);background:var(--surface,#fff);flex-shrink:0}'
    + '.evb-ava{width:36px;height:36px;border-radius:50%;background:var(--coral,#1E40AF);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:15px;flex-shrink:0}'
    + '.evb-title{flex:1;min-width:0;line-height:1.25}'
    + '.evb-title b{display:block;font-size:14px;font-weight:600;color:var(--ink,#222)}'
    + '.evb-title span{font-size:11.5px;color:var(--trust-green,#2D9F6F);font-weight:500}'
    + '.evb-iconbtn{width:30px;height:30px;border:none;background:none;border-radius:6px;cursor:pointer;color:var(--ink-muted,#6a6a6a);display:flex;align-items:center;justify-content:center;flex-shrink:0}'
    + '.evb-iconbtn:hover{background:var(--canvas-alt,#f7f7f7);color:var(--ink,#222)}'
    + '.evb-iconbtn svg{width:17px;height:17px}'
    + '.evb-body{flex:1;overflow-y:auto;padding:16px 14px;background:var(--canvas-alt,#f7f7f7);display:flex;flex-direction:column;gap:10px}'
    + '.evb-row{display:flex;gap:8px;max-width:100%}'
    + '.evb-row.u{justify-content:flex-end}'
    + '.evb-msg{max-width:82%;padding:10px 13px;border-radius:14px;font-size:13.5px;line-height:1.6;word-wrap:break-word}'
    + '.evb-row.b .evb-msg{background:#fff;color:var(--ink-secondary,#3f3f3f);border:1px solid var(--hairline-light,#ebebeb);border-bottom-left-radius:4px}'
    + '.evb-row.u .evb-msg{background:var(--coral,#1E40AF);color:#fff;border-bottom-right-radius:4px}'
    + '.evb-msg a{color:var(--coral,#1E40AF);font-weight:600;text-decoration:underline}'
    + '.evb-row.u .evb-msg a{color:#fff}'
    + '.evb-time{font-size:10.5px;color:var(--ink-faint,#929292);margin:2px 4px 0;text-align:right}'
    + '.evb-row.b .evb-time{text-align:left}'
    + '.evb-wrap{display:flex;flex-direction:column;max-width:82%}'
    + '.evb-typing{display:flex;gap:4px;padding:12px 14px;background:#fff;border:1px solid var(--hairline-light,#ebebeb);border-radius:14px;border-bottom-left-radius:4px;width:fit-content}'
    + '.evb-typing i{width:6px;height:6px;border-radius:50%;background:var(--ink-faint,#929292);animation:evbBounce 1.2s infinite}'
    + '.evb-typing i:nth-child(2){animation-delay:.15s}.evb-typing i:nth-child(3){animation-delay:.3s}'
    + '@keyframes evbBounce{0%,60%,100%{transform:translateY(0);opacity:.5}30%{transform:translateY(-4px);opacity:1}}'
    + '.evb-chips{display:flex;flex-wrap:wrap;gap:6px;padding:0 14px 10px;background:var(--canvas-alt,#f7f7f7);flex-shrink:0}'
    + '.evb-chip{background:#fff;border:1px solid var(--coral,#1E40AF);color:var(--coral,#1E40AF);border-radius:999px;padding:6px 12px;font-size:12px;font-weight:600;cursor:pointer;font-family:inherit;transition:background .15s ease}'
    + '.evb-chip:hover{background:var(--coral-light,#E7ECFB)}'
    + '.evb-form{display:flex;gap:8px;padding:10px 12px;border-top:1px solid var(--hairline-light,#ebebeb);background:#fff;flex-shrink:0}'
    + '.evb-form input{flex:1;height:40px;border:1px solid var(--hairline,#ddd);border-radius:999px;padding:0 14px;font-size:13.5px;font-family:inherit;color:var(--ink,#222);outline:none}'
    + '.evb-form input:focus{border-color:var(--ink,#222);box-shadow:inset 0 0 0 1px var(--ink,#222)}'
    + '.evb-send{width:40px;height:40px;border-radius:50%;border:none;background:var(--coral,#1E40AF);color:#fff;cursor:pointer;display:flex;align-items:center;justify-content:center;flex-shrink:0}'
    + '.evb-send:disabled{opacity:.45;cursor:default}'
    + '.evb-send svg{width:17px;height:17px}'
    + '.evb-foot{font-size:10.5px;color:var(--ink-faint,#929292);text-align:center;padding:0 0 8px;background:#fff;flex-shrink:0}'
    + '.evb-foot a{color:var(--ink-muted,#6a6a6a)}'
    /* ---- Mobile (<=768px) ------------------------------------------------
       Touch targets to ~44px, 16px input (stops iOS zoom-on-focus), dynamic
       viewport units so the panel resizes when the on-screen keyboard opens,
       and safe-area insets for notched iPhones. */
    + '@media (max-width:768px){'
    +   '.evb-fab{right:max(16px,env(safe-area-inset-right));bottom:max(16px,env(safe-area-inset-bottom));width:56px;height:56px}'
    +   '.evb-iconbtn{width:44px;height:44px;min-height:44px}'
    +   '.evb-iconbtn svg{width:19px;height:19px}'
    +   '.evb-form{gap:8px}'
    +   '.evb-form input{height:44px;font-size:16px}'
    +   '.evb-send{width:44px;height:44px;min-height:44px;flex-shrink:0}'
    +   '.evb-send svg{width:19px;height:19px}'
    +   '.evb-chip{min-height:40px;padding:10px 14px}'
    + '}'
    /* Phone: panel fills the screen edge-to-edge. 100dvh tracks the visible
       area when the keyboard opens, so the input stays reachable. */
    + '@media (max-width:480px){'
    +   '.evb-panel{right:8px;left:8px;bottom:8px;width:auto;height:78vh;max-height:78vh}'
    +   '@supports (height:100dvh){.evb-panel{height:min(78dvh,620px);max-height:78dvh;bottom:max(8px,env(safe-area-inset-bottom))}}'
    +   '.evb-fab{right:16px;bottom:max(16px,env(safe-area-inset-bottom));width:52px;height:52px}'
    + '}'
    /* Very short landscape phones: keep the panel inside the viewport. */
    + '@media (max-height:480px) and (orientation:landscape){'
    +   '.evb-panel{height:88vh;max-height:88vh;bottom:6px}'
    + '}'
    + '@media print{.evb-fab,.evb-panel{display:none!important}}';

  var ICON_CHAT = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/></svg>';

  var el = {}, msgs = [], booted = false;

  function nowStamp() {
    var d = new Date();
    return d.getHours().toString().padStart(2, '0') + ':' + d.getMinutes().toString().padStart(2, '0');
  }

  function save() {
    try {
      sessionStorage.setItem(KEY, JSON.stringify({
        m: msgs.slice(-60), open: el.panel.classList.contains('evb-open'), c: convo
      }));
    } catch (e) {}
  }
  function load() {
    try { return JSON.parse(sessionStorage.getItem(KEY) || 'null'); } catch (e) { return null; }
  }

  function scroll() { el.body.scrollTop = el.body.scrollHeight; }

  function addMsg(role, text, ts, skipSave) {
    var row = document.createElement('div');
    row.className = 'evb-row ' + (role === 'user' ? 'u' : 'b');
    var wrap = document.createElement('div');
    wrap.className = 'evb-wrap';
    var m = document.createElement('div');
    m.className = 'evb-msg';
    m.innerHTML = text;
    var t = document.createElement('div');
    t.className = 'evb-time';
    t.textContent = ts || nowStamp();
    wrap.appendChild(m); wrap.appendChild(t); row.appendChild(wrap);
    el.body.appendChild(row);
    scroll();
    if (!skipSave) { msgs.push({ r: role, t: text, ts: ts || nowStamp() }); save(); }
  }

  function setChips(list) {
    el.chips.innerHTML = '';
    (list || []).slice(0, 4).forEach(function (c) {
      if (!c) return;
      var b = document.createElement('button');
      b.className = 'evb-chip';
      b.type = 'button';
      b.textContent = c;
      b.addEventListener('click', function () { send(c); });
      el.chips.appendChild(b);
    });
  }

  function typing(on) {
    var ex = el.body.querySelector('.evb-typing');
    if (on) {
      if (ex) return;
      var d = document.createElement('div');
      d.className = 'evb-typing';
      d.innerHTML = '<i></i><i></i><i></i>';
      el.body.appendChild(d); scroll();
    } else if (ex) ex.remove();
  }

  function send(raw) {
    var text = String(raw || '').trim();
    if (!text) return;
    addMsg('user', text.replace(/</g, '&lt;'));
    setChips([]);
    el.input.value = '';
    typing(true);
    var ctx = getContext();
    var t0 = Date.now();

    function deliver(r) {
      // keep a minimum "thinking" beat so replies never snap in jarringly
      var wait = Math.max(0, 420 - (Date.now() - t0));
      setTimeout(function () {
        typing(false);
        addMsg('bot', r.text);
        setChips(r.chips && r.chips.length ? r.chips : ctx.chips);
        save();
      }, wait);
    }

    // Deterministic multi-turn flows stay local (instant + predictable).
    if (convo.pending) { deliver(respond(text, ctx)); return; }

    // No endpoint available (static hosting / no key) -> offline engine.
    if (apiState === 'off' || typeof fetch !== 'function') { deliver(respond(text, ctx)); return; }

    respondRemote(ctx).then(function (remote) {
      deliver(remote || respond(text, ctx));
    });
  }

  function greet() {
    var ctx = getContext();
    var hi = ctx.name ? 'Hi ' + String(ctx.name).split(' ')[0] + '!' : 'Hi there!';
    var where = ctx.page !== 'index' ? " I can see you're on <b>" + ctx.pageName + "</b>." : '';
    var who = ctx.role === 'supplier' ? " I can help with listings, enquiries, availability and payouts."
            : ctx.role === 'customer' ? " I can help with your quotes, bookings and payments."
            : " I can help you plan an event, or get your venue or planning business listed.";
    addMsg('bot', hi + " I'm the <b>Eventara Assistant</b>." + where + who);
    setChips(ctx.chips);
  }

  function openPanel() {
    el.panel.classList.add('evb-open');
    el.panel.setAttribute('aria-hidden', 'false');
    el.fab.classList.add('evb-hidden');
    el.fab.setAttribute('aria-expanded', 'true');
    if (!booted) { booted = true; if (!msgs.length) greet(); }
    setTimeout(function () { el.input.focus(); scroll(); }, 220);
    save();
  }
  function closePanel() {
    el.panel.classList.remove('evb-open');
    el.panel.setAttribute('aria-hidden', 'true');
    el.fab.classList.remove('evb-hidden');
    el.fab.setAttribute('aria-expanded', 'false');
    save();
  }
  function clearChat() {
    msgs = []; convo = { pending: null, misses: 0, last: null };
    el.body.innerHTML = '';
    greet(); save();
  }

  function build() {
    var style = document.createElement('style');
    style.textContent = css;
    document.head.appendChild(style);

    el.fab = document.createElement('button');
    el.fab.className = 'evb-fab';
    el.fab.setAttribute('aria-label', 'Open the Eventara assistant');
    el.fab.setAttribute('aria-expanded', 'false');
    el.fab.innerHTML = ICON_CHAT + '<span class="evb-dot"></span>';

    el.panel = document.createElement('div');
    el.panel.className = 'evb-panel';
    el.panel.setAttribute('role', 'dialog');
    el.panel.setAttribute('aria-label', 'Eventara assistant');
    el.panel.setAttribute('aria-hidden', 'true');
    el.panel.innerHTML = ''
      + '<div class="evb-head">'
      +   '<div class="evb-ava">E</div>'
      +   '<div class="evb-title"><b>Eventara Assistant</b><span>● Always here to help</span></div>'
      +   '<button class="evb-iconbtn evb-clear" aria-label="Clear conversation and start over" title="Start over"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/></svg></button>'
      +   '<button class="evb-iconbtn evb-min" aria-label="Minimise chat" title="Minimise"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M6 18 18 6M6 6l12 12"/></svg></button>'
      + '</div>'
      + '<div class="evb-body" role="log" aria-live="polite" aria-atomic="false"></div>'
      + '<div class="evb-chips"></div>'
      + '<form class="evb-form"><input type="text" placeholder="Ask me anything…" aria-label="Type your message" autocomplete="off"><button class="evb-send" type="submit" aria-label="Send message"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/></svg></button></form>'
      + '<div class="evb-foot">Automated assistant · <a href="faq.html">Help Centre</a></div>';

    document.body.appendChild(el.fab);
    document.body.appendChild(el.panel);

    el.body = el.panel.querySelector('.evb-body');
    el.chips = el.panel.querySelector('.evb-chips');
    el.input = el.panel.querySelector('input');
    el.form = el.panel.querySelector('.evb-form');

    el.fab.addEventListener('click', openPanel);
    el.panel.querySelector('.evb-min').addEventListener('click', closePanel);
    el.panel.querySelector('.evb-clear').addEventListener('click', clearChat);
    el.form.addEventListener('submit', function (e) { e.preventDefault(); send(el.input.value); });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && el.panel.classList.contains('evb-open')) closePanel();
    });

    // restore session
    var st = load();
    if (st && st.m && st.m.length) {
      msgs = st.m;
      if (st.c) convo = st.c;
      msgs.forEach(function (m) { addMsg(m.r, m.t, m.ts, true); });
      booted = true;
      var ctx = getContext();
      setChips(ctx.chips);
      if (st.open) openPanel();
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', build);
  else build();

  // expose for debugging / future LLM swap
  window.EventaraBot = { respond: respond, getContext: getContext, KB: KB, open: function () { openPanel(); } };
})();
