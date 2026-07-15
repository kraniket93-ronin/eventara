/* ============================================================
   EVENTARA — Shared Interactions
   ============================================================ */

document.addEventListener('DOMContentLoaded', () => {
  initNavbar();
  initScrollAnimations();
  initCounters();
  initMultiStepForm();
  initMobileMenu();
  initTabs();
  initSmoothScroll();
});

/* ============================================================
   1. NAVBAR — Scroll Effect & Floating
   ============================================================ */
function initNavbar() {
  const navbar = document.querySelector('.navbar');
  if (!navbar) return;

  let lastScroll = 0;
  window.addEventListener('scroll', () => {
    const currentScroll = window.scrollY;
    if (currentScroll > 40) {
      navbar.classList.add('scrolled');
    } else {
      navbar.classList.remove('scrolled');
    }
    lastScroll = currentScroll;
  }, { passive: true });
}

/* ============================================================
   2. SCROLL ANIMATIONS — IntersectionObserver
   ============================================================ */
function initScrollAnimations() {
  const animatedElements = document.querySelectorAll('.fade-in, .fade-in-left, .fade-in-right, .scale-in');
  if (!animatedElements.length) return;

  // Respect reduced motion preference
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    animatedElements.forEach(el => el.classList.add('visible'));
    return;
  }

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.15,
    rootMargin: '0px 0px -40px 0px'
  });

  animatedElements.forEach(el => observer.observe(el));
}

/* ============================================================
   3. COUNTER ANIMATIONS — Count Up on Scroll
   ============================================================ */
function initCounters() {
  const counters = document.querySelectorAll('[data-count]');
  if (!counters.length) return;

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        animateCounter(entry.target);
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.5 });

  counters.forEach(el => observer.observe(el));
}

function animateCounter(element) {
  const target = parseInt(element.getAttribute('data-count'), 10);
  const suffix = element.getAttribute('data-suffix') || '';
  const prefix = element.getAttribute('data-prefix') || '';
  const duration = 2000;
  const step = target / (duration / 16);
  let current = 0;

  function update() {
    current += step;
    if (current >= target) {
      element.textContent = prefix + formatNumber(target) + suffix;
      return;
    }
    element.textContent = prefix + formatNumber(Math.floor(current)) + suffix;
    requestAnimationFrame(update);
  }

  requestAnimationFrame(update);
}

function formatNumber(num) {
  if (num >= 1000) {
    return (num / 1000).toFixed(num % 1000 === 0 ? 0 : 1) + 'K';
  }
  return num.toLocaleString('en-IN');
}

/* ============================================================
   4. MULTI-STEP FORM
   ============================================================ */
function initMultiStepForm() {
  const form = document.querySelector('.multi-step-form');
  if (!form) return;

  const steps = form.querySelectorAll('.form-step');
  const progressDots = document.querySelectorAll('.form-progress .step-dot');
  const progressLines = document.querySelectorAll('.form-progress .step-line');
  const progressLabels = document.querySelectorAll('.form-progress .step-label');
  let currentStep = 0;

  // Navigation buttons
  form.addEventListener('click', (e) => {
    if (e.target.closest('[data-step-next]')) {
      e.preventDefault();
      if (currentStep < steps.length - 1) {
        goToStep(currentStep + 1);
      }
    }
    if (e.target.closest('[data-step-prev]')) {
      e.preventDefault();
      if (currentStep > 0) {
        goToStep(currentStep - 1);
      }
    }
    if (e.target.closest('[data-step-submit]')) {
      e.preventDefault();
      showSubmitConfirmation();
    }
  });

  function goToStep(stepIndex) {
    // Hide current
    steps[currentStep].classList.remove('active');

    // Update progress for previous step
    if (stepIndex > currentStep) {
      progressDots[currentStep].classList.remove('active');
      progressDots[currentStep].classList.add('completed');
      progressDots[currentStep].innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>`;
      if (progressLines[currentStep]) {
        progressLines[currentStep].classList.add('completed');
      }
    } else {
      progressDots[currentStep].classList.remove('active');
      progressDots[currentStep].classList.remove('completed');
      progressDots[currentStep].textContent = currentStep + 1;
      if (progressLines[currentStep - 1]) {
        progressLines[currentStep - 1].classList.remove('completed');
      }
    }

    // Show new step
    currentStep = stepIndex;
    steps[currentStep].classList.add('active');
    progressDots[currentStep].classList.add('active');
    progressDots[currentStep].classList.remove('completed');
    progressDots[currentStep].textContent = currentStep + 1;

    // Update labels
    progressLabels.forEach((label, i) => {
      label.classList.toggle('active', i === currentStep);
    });

    // Scroll to top of form
    form.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  function showSubmitConfirmation() {
    const lastStep = steps[steps.length - 1];
    lastStep.innerHTML = `
      <div class="text-center" style="padding: 48px 0;">
        <div style="width: 72px; height: 72px; background: var(--trust-green-light); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 24px;">
          <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="var(--trust-green)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>
        </div>
        <h3 class="display-md" style="margin-bottom: 12px;">Brief Submitted!</h3>
        <p class="body-lg text-secondary" style="max-width: 460px; margin: 0 auto 32px;">Your brief has been sent to Paandora Grand Udaipur, The Ananta Udaipur and Aurika, Udaipur. Itemised quotes arrive within the 48-hour SLA — we'll line them up side by side for you.</p>
        <a href="compare.html" class="btn btn-primary">Preview Quote Comparison</a>
        <a href="index.html" class="btn btn-ghost">Back to Home</a>
      </div>
    `;
    // Mark all as completed
    progressDots.forEach(dot => {
      dot.classList.add('completed');
      dot.classList.remove('active');
      dot.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>`;
    });
    progressLines.forEach(line => line.classList.add('completed'));
  }
}

/* ============================================================
   5. MOBILE MENU
   ============================================================ */
function initMobileMenu() {
  const hamburger = document.querySelector('.hamburger');
  const mobileMenu = document.querySelector('.mobile-menu');
  if (!hamburger || !mobileMenu) return;

  hamburger.addEventListener('click', () => {
    hamburger.classList.toggle('active');
    mobileMenu.classList.toggle('active');
    document.body.style.overflow = mobileMenu.classList.contains('active') ? 'hidden' : '';
  });

  // Close on link click
  mobileMenu.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
      hamburger.classList.remove('active');
      mobileMenu.classList.remove('active');
      document.body.style.overflow = '';
    });
  });

  // Close on outside click
  document.addEventListener('click', (e) => {
    if (!hamburger.contains(e.target) && !mobileMenu.contains(e.target)) {
      hamburger.classList.remove('active');
      mobileMenu.classList.remove('active');
      document.body.style.overflow = '';
    }
  });
}

/* ============================================================
   6. TABS
   ============================================================ */
function initTabs() {
  document.querySelectorAll('[data-tabs]').forEach(tabContainer => {
    const buttons = tabContainer.querySelectorAll('[data-tab]');
    const panels = tabContainer.querySelectorAll('[data-tab-panel]');

    buttons.forEach(btn => {
      btn.addEventListener('click', () => {
        const target = btn.getAttribute('data-tab');

        buttons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        panels.forEach(panel => {
          panel.style.display = panel.getAttribute('data-tab-panel') === target ? 'block' : 'none';
        });
      });
    });
  });
}

/* ============================================================
   7. SMOOTH SCROLL
   ============================================================ */
function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', (e) => {
      const targetId = anchor.getAttribute('href');
      if (targetId === '#') return;
      
      const target = document.querySelector(targetId);
      if (target) {
        e.preventDefault();
        target.scrollIntoView({
          behavior: 'smooth',
          block: 'start'
        });
      }
    });
  });
}

/* ============================================================
   8. LIGHTBOX (Provider Gallery)
   ============================================================ */
function openLightbox(imageSrc) {
  const overlay = document.createElement('div');
  overlay.style.cssText = `
    position: fixed; inset: 0; background: rgba(0,0,0,0.85);
    z-index: 9999; display: flex; align-items: center; justify-content: center;
    cursor: pointer; animation: fadeIn 0.25s ease;
  `;
  overlay.innerHTML = `
    <img src="${imageSrc}" alt="Gallery image" style="max-width: 90%; max-height: 90%; border-radius: 12px; object-fit: contain;" />
    <button style="position: absolute; top: 24px; right: 24px; width: 44px; height: 44px;
      background: rgba(255,255,255,0.15); border: none; border-radius: 50%; color: white;
      font-size: 24px; cursor: pointer; display: flex; align-items: center; justify-content: center;">
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg>
    </button>
  `;
  overlay.addEventListener('click', () => overlay.remove());
  document.body.appendChild(overlay);
}

/* ============================================================
   9. SEARCH FILTER INTERACTIONS
   ============================================================ */
document.addEventListener('click', (e) => {
  const pill = e.target.closest('.filter-pill');
  if (pill && !pill.closest('.filter-pills-radio')) {
    pill.classList.toggle('active');
  }
});

/* ============================================================
   10. DASHBOARD SIDEBAR TOGGLE (Mobile)
   ============================================================ */
function toggleSidebar() {
  const sidebar = document.querySelector('.sidebar');
  if (sidebar) {
    sidebar.classList.toggle('mobile-open');
  }
}

/* ============================================================
   11. BOOKING PAGE INTERACTIONS
   ============================================================ */
document.addEventListener('click', (e) => {
  // Payment method selection
  const paymentOption = e.target.closest('.payment-option');
  if (paymentOption) {
    document.querySelectorAll('.payment-option').forEach(opt => opt.classList.remove('selected'));
    paymentOption.classList.add('selected');
    const radio = paymentOption.querySelector('input[type="radio"]');
    if (radio) radio.checked = true;
  }
});
