/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

package org.apache.jmeter.reporters;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.io.Serializable;
import java.net.Socket;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.jmeter.engine.util.NoThreadClone;
import org.apache.jmeter.samplers.Remoteable;
import org.apache.jmeter.samplers.SampleEvent;
import org.apache.jmeter.samplers.SampleListener;
import org.apache.jmeter.samplers.SampleResult;
import org.apache.jmeter.testelement.AbstractTestElement;
import org.apache.jmeter.testelement.TestStateListener;
import org.apache.jmeter.threads.JMeterContextService;
import org.apache.jmeter.util.JMeterUtils;
import org.apache.jmeter.visualizers.RunningSample;

/**
 * Generate a summary of the test run so far to the log file and/or standard
 * output. Both running and differential totals are shown. Output is generated
 * every n seconds (default 3 minutes) on the appropriate time boundary, so that
 * multiple test runs on the same time will be synchronised.
 *
 * This is mainly intended for batch (non-GUI) runs
 *
 * Note that the RunningSample start and end times relate to the samples,
 * not the reporting interval.
 *
 * Since the first sample in a delta is likely to have started in the previous reporting interval,
 * this means that the delta interval is likely to be longer than the reporting interval.
 *
 * Also, the sum of the delta intervals will be larger than the overall elapsed time.
 *
 * Data is accumulated according to the test element name.
 *
 */
public class Summariser extends AbstractTestElement
    implements Serializable, SampleListener, TestStateListener, NoThreadClone, Remoteable {

    /*
     * N.B. NoThreadClone is used to ensure that the testStarted() methods will share the same
     * instance as the sampleOccured() methods, so the testStarted() method can fetch the
     * Totals accumulator object for the samples to be stored in.
     */

    private static final long serialVersionUID = 233L;
    /** interval between summaries (in seconds) default 1 minutes */
    private static final long INTERVAL = JMeterUtils.getPropDefault("jm.interval", 60) * 1000; //$NON-NLS-1$
    private static final String HOST = JMeterUtils.getPropDefault("jm.host", "<UNDEFINED_HOST>");
    private static final int PORT = JMeterUtils.getPropDefault("jm.port", 4444);
	private final static int OUTPUT_WIDTH = JMeterUtils.getPropDefault("jm.output_width", 105);
    private PerfMonThread perfmon = null;

    /**
     * Lock used to protect accumulators update + instanceCount update
     */
    private static final Object lock = new Object();

    /*
     * This map allows summarisers with the same name to contribute to the same totals.
     */
    //@GuardedBy("accumulators") - needed to ensure consistency between this and instanceCount
    private static final Map<String, Totals> accumulators = new ConcurrentHashMap<String, Totals>();

    //@GuardedBy("accumulators")
    private static int instanceCount; // number of active tests

    /*
     * Cached copy of Totals for this instance.
     * The variables do not need to be synchronised,
     * as they are not shared between threads
     * However the contents do need to be synchronized.
     */
    //@GuardedBy("myTotals")
    private transient Totals myTotals = null;

    // Name of the accumulator. Set up by testStarted().
    private transient String myName;

    /*
     * Constructor is initially called once for each occurrence in the test plan.
     * For GUI, several more instances are created.
     * Then clear is called at start of test.
     * Called several times during test startup.
     * The name will not necessarily have been set at this point.
     */
    public Summariser() {
        super();
        synchronized (lock) {
            accumulators.clear();
            instanceCount=0;
        }
    }

    /**
     * Constructor for use during startup (intended for non-GUI use)
     *
     * @param name of summariser
     */
    public Summariser(String name) {
        this();
        setName(name);
    }

    /*
     * Contains the items needed to collect stats for a summariser
     *
     */
    private static class Totals {

        /** Time of last summary (to prevent double reporting) */
        private long last = 0;   //The time of last outInterval occurred
        private long next = 0;   //The time of next outInterval in schedule
        private long second = 0; //The begin time of the second INTERVAL
        private long beforeLast = 0; //The time of the one before "last"

        private final RunningSample delta = new RunningSample("DELTA",0);
        private final RunningSample total = new RunningSample("TOTAL",0);
        private RunningSample lastTotal = null;

        /**
         * Add the delta values to the total values and clear the delta
         */
        private void moveDelta(long now) {
        	beforeLast = last;
        	last = now;
			if (second == 0) { //First Interval
				second = now;
			} else {
				lastTotal = new RunningSample(total);
				total.addSample(delta);
				delta.clear();
			}
            while (next - now < 1000) { next += INTERVAL; }
        }
    }

    private void outInterval(Calendar now, RunningSample s) {
    	PerfMonRecords record = (perfmon == null) ? PerfMonRecords.INVALID : perfmon.outRecords();
    	System.out.printf("%tT  Throughput=%6.2f  RespT=%5.2f  CPU%%=%3.0f  DiskQ=%3.0f  Busy=%2d  MinT=%5.2f  MaxT=%5.2f  Error= %d%n", now,
    			s.getRate(), s.getAverage()/1000.0, record.cpu, record.dql, JMeterContextService.getThreadCounts().activeThreads,
    			s.getMin()/1000.0, s.getMax()/1000.0, s.getErrorCount());
    }
    
    private void outSummary(Calendar now, Totals myTotals) {
    	if (myTotals == null) {
    		System.out.println("Average unavailable due to no sample result.");
    		return;
    	}
    	
    	Calendar begin = Calendar.getInstance();
    	Calendar end = Calendar.getInstance();
    	RunningSample summary = new RunningSample("SUMMARY",0);;
    	
		synchronized (myTotals) {
			begin.setTimeInMillis(myTotals.second);
			if (now.getTimeInMillis() > myTotals.last + INTERVAL / 2) {
				summary.addSample(myTotals.total);
				end.setTimeInMillis(myTotals.last);
			} else {
				summary.addSample(myTotals.lastTotal);
				end.setTimeInMillis(myTotals.beforeLast);
			}
		}
		
		if (end.getTimeInMillis() - begin.getTimeInMillis() < 1000) {
			System.out.println("Average unavailable due to insufficient sample result.");
		} else {
			float aveCPU = (perfmon == null) ? -1 : perfmon.averageCPU();
			System.out.printf("%tT  <Test ended> Average of (%tT , %tT]: Throughput= %.2f  RespT= %.2f  CPU%%= %.0f%n",
    				Calendar.getInstance(), begin, end, summary.getRate(), summary.getAverage()/1000.0, aveCPU);
		}
    }
    /**
     * Accumulates the sample in two SampleResult objects - one for running
     * totals, and the other for deltas.
     *
     * @see org.apache.jmeter.samplers.SampleListener#sampleOccurred(org.apache.jmeter.samplers.SampleEvent)
     */
    @Override
    public void sampleOccurred(SampleEvent e) {
        SampleResult s = e.getResult();

        Calendar now = Calendar.getInstance();

        RunningSample myDelta = null;
        boolean reportNow = false;

        /*
         * Have we reached the reporting boundary?
         * Need to allow for a margin of error, otherwise can miss the slot.
         * Also need to check we've not hit the window already
         */
        synchronized (myTotals) {
            if (s != null) {
                myTotals.delta.addSample(s);
            }

            if (now.getTimeInMillis() >= myTotals.next) {
                reportNow = true;

                // copy the data to minimize the synch time
                myDelta = new RunningSample(myTotals.delta);
                myTotals.moveDelta(now.getTimeInMillis());
            }
        }
        if (reportNow) {
            outInterval(now, myDelta);
        }
    }

    /** {@inheritDoc} */
    @Override
    public void sampleStarted(SampleEvent e) {
        // not used
    }

    /** {@inheritDoc} */
    @Override
    public void sampleStopped(SampleEvent e) {
        // not used
    }

    /*
     * The testStarted/testEnded methods are called at the start and end of a test.
     *
     * However, when a test is run on multiple nodes, there is no guarantee that all the
     * testStarted() methods will be called before all the threadStart() or sampleOccurred()
     * methods for other threads - nor that testEnded() will only be called after all
     * sampleOccurred() calls. The ordering is only guaranteed within a single test.
     *
     */


    /** {@inheritDoc} */
    @Override
    public void testStarted() {
        testStarted("local");
    }

    /** {@inheritDoc} */
    @Override
    public void testEnded() {
        testEnded("local");
    }

    /**
     * Called once for each Summariser in the test plan.
     * There may be more than one summariser with the same name,
     * however they will all be called before the test proper starts.
     * <p>
     * However, note that this applies to a single test only.
     * When running in client-server mode, testStarted() may be
     * invoked after sampleOccurred().
     * <p>
     * {@inheritDoc}
     */
    @Override
    public void testStarted(String host) {
        synchronized (lock) {
            myName = getName();
            myTotals = accumulators.get(myName);
            if (myTotals == null){
                myTotals = new Totals();
                myTotals.next = System.currentTimeMillis() + INTERVAL;
                accumulators.put(myName, myTotals);
            }
            instanceCount++;
        }

        String msg = String.format("PerfMon(CPU, DiskQ) on %s:%d.", HOST, PORT);
        try {
			perfmon = new PerfMonThread(HOST, PORT);
			perfmon.start();
		} catch (UnknownHostException e) {
			msg = String.format("Failed to PerfMon on %s:%d - %s: %s", HOST, PORT, e.getClass().getSimpleName(), e.getMessage());
		} catch (IOException e) {
			msg = String.format("Failed to PerfMon on %s:%d - %s: %s", HOST, PORT, e.getClass().getSimpleName(), e.getMessage());
		}
        System.out.printf("%tT  <Test started> %s%n", Calendar.getInstance(), msg);
    }

    /**
     * Called from a different thread as testStarted() but using the same instance.
     * So synch is needed to fetch the accumulator, and the myName field will already be set up.
     * <p>
     * {@inheritDoc}
     */
    @Override
    public void testEnded(String host) {
    	if (perfmon != null) {
    		perfmon.terminate();
    		try {
				perfmon.join();
			} catch (InterruptedException e) {
				e.printStackTrace();
			}
    	}
        Set<Entry<String, Totals>> totals = null;
        synchronized (lock) {
            instanceCount--;
            if (instanceCount <= 0){
                totals = accumulators.entrySet();
            }
        }
        if (totals == null) {// We're not done yet
        	outSummary(null, null);
            return;
        }
        for(Map.Entry<String, Totals> entry : totals){
            Totals total = entry.getValue();
            Calendar now = Calendar.getInstance();
            // Only print final delta if there were some samples in the delta
            // and there has been at least one sample reported previously
            if (now.getTimeInMillis() - total.last > INTERVAL/10 && total.delta.getNumSamples() > 0 && total.total.getNumSamples() > 0) {
                outInterval(now, total.delta);
            }
            outSummary(now, total);
        }
    }
    

    private static class PerfMonRecords {
    	private List<Float> CPUs = null;
    	private List<Float> DQLs = null;
    	public float cpu = -1;
    	public float dql = -1;
    	public static PerfMonRecords INVALID = new PerfMonRecords(-1, -1);
    	
    	private void init() {
    		CPUs = new ArrayList<Float>((int)INTERVAL/1000);
    		DQLs = new ArrayList<Float>((int)INTERVAL/1000);
    	}
    	public PerfMonRecords() {
    		init();
    	}
    	private PerfMonRecords(List<Float> CPUs, List<Float> DQLs) {
    		this.CPUs = CPUs;
    		this.DQLs = DQLs;
    	}
    	private PerfMonRecords(float cpu, float dql) {
    		this.cpu = cpu;
    		this.dql = dql;
    	}

    	public PerfMonRecords popRecords() {
    		PerfMonRecords ret = new PerfMonRecords(CPUs, DQLs);
    		init();
    		return ret;
    	}
    	
    	public void add(String cpu_dql_line) {
			if (cpu_dql_line != null) {
				String[] values = cpu_dql_line.split("\t");
				cpu = Float.parseFloat(values[0]);
				dql = Float.parseFloat(values[1]);
				assert (cpu >= 0 && dql >= 0);
				CPUs.add(cpu);
				DQLs.add(dql);
			}
    	}
    	
    	public static String formatValues(List<Float> values, String name, String format, String separator) {
    		StringBuilder sb = new StringBuilder(String.format("%7s:  (", name));
    		int lineStart = 0;
			for (float value : values) {
				String str = String.format(format, value);
				if (sb.length() - lineStart + str.length() + 1 > OUTPUT_WIDTH) {
					sb.append(System.getProperty("line.separator"));
					lineStart = sb.length();
					sb.append("           ");
				}
				sb.append(str);
				if (sb.length() - lineStart != OUTPUT_WIDTH) {
					sb.append(separator);
				}
			}
    		sb.append(")/").append(values.size());
			return sb.toString();
    	}
    	public static float average(List<Float> values) {
    		if (values.size() == 0) {
    			return -1;
    		}
    		
    		float sum = 0;
			for (float value : values) {
				sum += value;
			}
			return sum / values.size();
    	}
    }
    
    private static class PerfMonThread extends Thread {
    	private Socket socket = null;
    	private PrintWriter pw = null;
    	private BufferedReader br = null;
    	private boolean terminate = false;
    	private PerfMonRecords records = new PerfMonRecords();

    	private int numOfSum = -1; //-1 means ignore the first result
    	private float sumCPU = 0;
    	private float lastCPU = 0;
    	public float averageCPU() {
    		if (numOfSum >= 2) {
    			return (sumCPU - lastCPU)/(numOfSum -1);
    		} else {
    			return -1;
    		}
    	}
    	
    	public PerfMonThread(String host, int port) throws UnknownHostException, IOException {
    		super("PerfMonThread@" + host + ":" + "port");
			socket = new Socket(host, port);
			pw = new PrintWriter(socket.getOutputStream(), true);
			br = new BufferedReader(new InputStreamReader(socket.getInputStream()));
			pw.println("test");
			br.readLine();
    	}
    	
    	@Override
    	public void run() {
			pw.println("metrics:cpu\tdisks");
			
    		while (!terminate) {	
    			String line = null;
				try {
					if (!br.ready()) {
						try { Thread.sleep(1000); } catch (InterruptedException e) { e.printStackTrace(); }
						continue;
					}
					line = br.readLine();
				} catch (IOException e) {
					e.printStackTrace();
					break;
				}
				records.add(line);
    		}
    		
    		try {
				while (br.readLine() != null) {}
				br.close();
				pw.close();
				socket.close();
			} catch (IOException e) {
				e.printStackTrace();
			}
    	}
    	
    	public void terminate() {
    		pw.println("exit");
    		terminate = true;
    	}
    	
    	public PerfMonRecords outRecords() {
    		PerfMonRecords old = records.popRecords();
    		old.cpu = PerfMonRecords.average(old.CPUs);
    		old.dql = PerfMonRecords.average(old.DQLs);
    		System.out.println(PerfMonRecords.formatValues(old.CPUs, "CPU", "%2.0f", " "));
    		if (old.dql >= 0.5) {
        		System.out.println(PerfMonRecords.formatValues(old.DQLs, "DiskQ", "%2.0f", " "));
    		}
    		
    		numOfSum ++;
    		if (numOfSum >= 1) {
    			sumCPU += old.cpu;
    			lastCPU = old.cpu;
    		}
    		
    		return old;
    	}
    }
}