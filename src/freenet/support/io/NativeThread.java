/* This code is part of Freenet. It is distributed under the GNU General
 * Public License, version 2 (or at your option any later version). See
 * http://www.gnu.org/ for further details of the GPL. */

package freenet.support.io;

import freenet.node.NodeStarter;
import freenet.support.LibraryLoader;
import freenet.support.Logger;

/**
 * Do *NOT* forget to call super.run() if you extend it!
 * 
 * @see http://archives.freenetproject.org/thread/20080214.235159.6deed539.en.html
 * @author Florent Daigni&egrave;re &lt;nextgens@freenetproject.org&gt;
 */
public class NativeThread extends Thread {
	public static final boolean _loadNative;
	private static boolean _disabled;
	public static final int JAVA_PRIORITY_RANGE = Thread.MAX_PRIORITY - Thread.MIN_PRIORITY;
	private final static int NATIVE_PRIORITY_BASE;
	public final static int NATIVE_PRIORITY_RANGE;
	private int currentPriority = Thread.MAX_PRIORITY;
	private boolean dontCheckRenice = false;

	public final static boolean HAS_THREE_NICE_LEVELS;
	public final static boolean HAS_ENOUGH_NICE_LEVELS;
	public final static boolean HAS_PLENTY_NICE_LEVELS;

	
	// TODO: Wire in.
	public static enum PriorityLevel {
		MIN_PRIORITY(1),
		LOW_PRIORITY(3),
		NORM_PRIORITY(5),
		HIGH_PRIORITY(7),
		MAX_PRIORITY(10);
		
		public final int value;
		
		PriorityLevel(int myValue) {
			value = myValue;
		}
		
		public static PriorityLevel fromValue(int value) {
			for(PriorityLevel level :PriorityLevel.values()) {
				if(level.value == value)
					return level;
			}
			
			throw new IllegalArgumentException();
		}
	}
	
	

	public static final int ENOUGH_NICE_LEVELS = PriorityLevel.values().length;
	public static final int MIN_PRIORITY = PriorityLevel.MIN_PRIORITY.value;
	public static final int LOW_PRIORITY = PriorityLevel.LOW_PRIORITY.value;
	public static final int NORM_PRIORITY = PriorityLevel.NORM_PRIORITY.value;
	public static final int HIGH_PRIORITY = PriorityLevel.HIGH_PRIORITY.value;
	public static final int MAX_PRIORITY = PriorityLevel.MAX_PRIORITY.value;
	
	

	static {
		Logger.minor(NativeThread.class, "Running init()");
		// Loading the NativeThread library isn't useful on macos
		boolean maybeLoadNative = ("Linux".equalsIgnoreCase(System.getProperty("os.name"))) && (NodeStarter.extBuildNumber > 18);
		Logger.debug(NativeThread.class, "Run init(): should loadNative="+maybeLoadNative);
		if(maybeLoadNative && LibraryLoader.loadNative("/freenet/support/io/", "NativeThread")) {
			NATIVE_PRIORITY_BASE = getLinuxPriority();
			NATIVE_PRIORITY_RANGE = 20 - NATIVE_PRIORITY_BASE;
			System.out.println("Using the NativeThread implementation (base nice level is "+NATIVE_PRIORITY_BASE+')');
			// they are 3 main prio levels
			HAS_THREE_NICE_LEVELS = NATIVE_PRIORITY_RANGE >= 3;
			HAS_ENOUGH_NICE_LEVELS = NATIVE_PRIORITY_RANGE >= ENOUGH_NICE_LEVELS;
			HAS_PLENTY_NICE_LEVELS = NATIVE_PRIORITY_RANGE >=JAVA_PRIORITY_RANGE;
			if(!(HAS_ENOUGH_NICE_LEVELS && HAS_THREE_NICE_LEVELS))
				System.err.println("WARNING!!! The JVM has been niced down to a level which won't allow it to schedule threads properly! LOWER THE NICE LEVEL!!");
			_loadNative = true;
		} else {
			// unused anyway
			NATIVE_PRIORITY_BASE = 0;
			NATIVE_PRIORITY_RANGE = 19;
			HAS_THREE_NICE_LEVELS = true;
			HAS_ENOUGH_NICE_LEVELS = true;
			HAS_PLENTY_NICE_LEVELS = true;
			_loadNative = false;
		}
		Logger.minor(NativeThread.class, "Run init(): _loadNative = "+_loadNative);
	}
	

	public NativeThread(String name, int priority, boolean dontCheckRenice) {
		super(name);
		this.currentPriority = priority;
		this.dontCheckRenice = dontCheckRenice;
	}
	
	public NativeThread(Runnable r, String name, int priority, boolean dontCheckRenice) {
		super(r, name);
		this.currentPriority = priority;
		this.dontCheckRenice = dontCheckRenice;
	}
	
	public NativeThread(ThreadGroup g, Runnable r, String name, int priority, boolean dontCheckRenice) {
		super(g, r, name);
		this.currentPriority = priority;
		this.dontCheckRenice = dontCheckRenice;
	}

	/**
	 * Set linux priority (JNI call)
	 * 
	 * @return true if successful, false otherwise.
	 */
	private static native boolean setLinuxPriority(int prio);
	
	/**
	 * Get linux priority (JNI call)
	 */
	private static native int getLinuxPriority();	
	
	@Override
	public final void run() {
		if(!setNativePriority(currentPriority))
			System.err.println("setNativePriority("+currentPriority+") has failed!");
		super.run();
		realRun();
	}
	
	public void realRun() {
		// Override this for convenience when doing new NativeThread() { ... }
	}
	
	/**
	 * Rescale java priority and set linux priority.
	 */
	private boolean setNativePriority(int prio) {
		Logger.minor(this, "setNativePriority("+prio+")");
		setPriority(prio);
		if(!_loadNative) {
			Logger.minor(this, "_loadNative is false");
			return true;
		}
		int realPrio = getLinuxPriority();
		if(_disabled) {
			Logger.normal(this, "Not setting native priority as disabled due to renicing");
			return false;
		}
		if(NATIVE_PRIORITY_BASE != realPrio && !dontCheckRenice) {
			/* The user has reniced freenet or we didn't use the PacketSender to create the thread
			 * either ways it's bad for us.
			 * 
			 * Let's disable the renicing as we can't rely on it anymore.
			 */
			_disabled = true;
			Logger.error(this, "Freenet has detected it has been reniced : THAT'S BAD, DON'T DO IT! Nice level detected statically: "+NATIVE_PRIORITY_BASE+" actual nice level: "+realPrio+" on "+this);
			System.err.println("Freenet has detected it has been reniced : THAT'S BAD, DON'T DO IT! Nice level detected statically: "+NATIVE_PRIORITY_BASE+" actual nice level: "+realPrio+" on "+this);
			new NullPointerException().printStackTrace();
			return false;
		}
		final int linuxPriority = NATIVE_PRIORITY_BASE + NATIVE_PRIORITY_RANGE - (NATIVE_PRIORITY_RANGE * (prio - MIN_PRIORITY)) / JAVA_PRIORITY_RANGE;
		if(linuxPriority == realPrio) return true; // Ok
		// That's an obvious coding mistake
		if(prio < currentPriority)
			throw new IllegalStateException("You're trying to set a thread priority" +
				" above the current value!! It's not possible if you aren't root" +
				" and shouldn't ever occur in our code. (asked="+prio+':'+linuxPriority+" currentMax="+
				+currentPriority+':'+NATIVE_PRIORITY_BASE+") SHOUDLN'T HAPPEN, please report!");
		Logger.minor(this, "Setting native priority to "+linuxPriority+" (base="+NATIVE_PRIORITY_BASE+") for "+this);
		return setLinuxPriority(linuxPriority);
	}
	
	public int getNativePriority() {
		return currentPriority;
	}

	public static boolean usingNativeCode() {
		return _loadNative && !_disabled;
	}
	
	public static String normalizeName(String name) {
		if(name.indexOf(" for ") != -1)
			name = name.substring(0, name.indexOf(" for "));
		if(name.indexOf("@") != -1)
			name = name.substring(0, name.indexOf("@"));
		if (name.indexOf("(") != -1)
			name = name.substring(0, name.indexOf("("));
		
		return name;
	}
	
	public String getNormalizedName() {
		return normalizeName(getName());
	}
}
